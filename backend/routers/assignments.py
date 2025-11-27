from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from datetime import datetime
import os
from ..database import get_db
from ..models import Assignment, Course, CourseStudent, Submission, User, ROLE_TEACHER, ROLE_STUDENT
from ..schemas import AssignmentCreate, AssignmentRead
from ..deps import get_current_user, require_role
import tempfile
import logging

# Primary attachments directory inside the project
DEFAULT_ATTACH_DIR = os.path.join("backend", "storage", "assignments")

# Try to create the primary directory. If permissions prevent that (e.g. a mounted
# volume owned by root), fall back to a writable temp location so the API remains
# functional instead of failing at import-time.
try:
    os.makedirs(DEFAULT_ATTACH_DIR, exist_ok=True)
    ATTACH_DIR = DEFAULT_ATTACH_DIR
except PermissionError:
    fallback = os.path.join(tempfile.gettempdir(), "plataforma_storage", "assignments")
    try:
        os.makedirs(fallback, exist_ok=True)
        ATTACH_DIR = fallback
        logging.warning("Permission denied creating %s; using fallback %s", DEFAULT_ATTACH_DIR, ATTACH_DIR)
    except Exception as e:
        # As a last resort, set ATTACH_DIR to system temp and log the error. The
        # application will still attempt writes and reads but they may fail later
        # with clearer errors at runtime.
        ATTACH_DIR = tempfile.gettempdir()
        logging.exception("Failed to create fallback attachments dir: %s", e)

router = APIRouter(prefix="/assignments", tags=["assignments"])

@router.post("/course/{course_id}", response_model=AssignmentRead)
def create_assignment(course_id: int, data: AssignmentCreate, db: Session = Depends(get_db), teacher: User = Depends(require_role(ROLE_TEACHER)), attachment: UploadFile | None = File(None)):
    course = db.query(Course).filter(Course.id == course_id, Course.teacher_id == teacher.id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Course not found or not owned")
    filename = None
    if attachment:
        if not attachment.filename.lower().endswith('.pdf'):
            raise HTTPException(status_code=400, detail="Attachment must be PDF")
        filename = f"assignment_{course_id}_{int(datetime.utcnow().timestamp())}_{attachment.filename}"
        with open(os.path.join(ATTACH_DIR, filename), 'wb') as f:
            f.write(attachment.file.read())
    assignment = Assignment(course_id=course.id, teacher_id=teacher.id, title=data.title, description=data.description, due_date=data.due_date, attachment_filename=filename)
    db.add(assignment)
    db.commit()
    db.refresh(assignment)
    return assignment

@router.get("/course/{course_id}", response_model=list[AssignmentRead])
def list_assignments(course_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    # Authorization: teachers see their assignments; students/parents see assignments without enforced enrollment checks
    q = db.query(Assignment).filter(Assignment.course_id == course_id)
    if user.role == ROLE_TEACHER:
        q = q.filter(Assignment.teacher_id == user.id)
    return q.all()

@router.get("/{assignment_id}", response_model=AssignmentRead)
def get_assignment(assignment_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    a = db.query(Assignment).filter(Assignment.id == assignment_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="Not found")
    # simple visibility checks: teachers must own the assignment; students/parents may view without enforced enrollment
    if user.role == ROLE_TEACHER and a.teacher_id != user.id:
        raise HTTPException(status_code=403, detail="Not your assignment")
    return a

@router.get("/{assignment_id}/attachment")
def download_attachment(assignment_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    a = db.query(Assignment).filter(Assignment.id == assignment_id).first()
    if not a or not a.attachment_filename:
        raise HTTPException(status_code=404, detail="Attachment not found")
    # reuse visibility checks: teachers must own the assignment; students may download without enforced enrollment
    if user.role == ROLE_TEACHER and a.teacher_id != user.id:
        raise HTTPException(status_code=403, detail="Not your assignment")
    path = os.path.join(ATTACH_DIR, a.attachment_filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="File missing")
    with open(path, 'rb') as f:
        return {"filename": a.attachment_filename, "content": f.read().decode('latin-1')}  # simplistic; real impl should stream bytes
