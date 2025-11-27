from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from datetime import datetime
import os
from ..database import get_db
from ..models import Submission, Assignment, CourseStudent, User, ROLE_STUDENT, ROLE_TEACHER
from ..schemas import SubmissionRead, GradeSubmission
from ..deps import get_current_user, require_role
import logging

SUBMIT_DIR = os.path.join("backend", "storage", "submissions")
os.makedirs(SUBMIT_DIR, exist_ok=True)

router = APIRouter(prefix="/submissions", tags=["submissions"])

@router.post("/assignment/{assignment_id}", response_model=SubmissionRead)
def upload_submission(assignment_id: int, file: UploadFile = File(...), db: Session = Depends(get_db), student: User = Depends(require_role(ROLE_STUDENT))):
    assignment = db.query(Assignment).filter(Assignment.id == assignment_id).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    # NOTE: Enrollment checks removed — allow uploads regardless of CourseStudent links.
    # Keep a light audit log of upload attempts for debugging/monitoring.
    logging.info("Upload attempt (no-enrollment-check): assignment_id=%s, assignment.course_id=%s, student.id=%s", assignment_id, assignment.course_id, getattr(student, 'id', None))
    filename = f"submission_{assignment_id}_{student.id}_{int(datetime.utcnow().timestamp())}_{file.filename}"
    with open(os.path.join(SUBMIT_DIR, filename), 'wb') as f:
        f.write(file.file.read())
    submission = Submission(assignment_id=assignment.id, student_id=student.id, file_name=filename)
    db.add(submission)
    db.commit()
    db.refresh(submission)
    return submission

@router.get("/assignment/{assignment_id}", response_model=list[SubmissionRead])
def list_my_submissions(assignment_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    q = db.query(Submission).filter(Submission.assignment_id == assignment_id)
    if user.role == ROLE_STUDENT:
        q = q.filter(Submission.student_id == user.id)
    elif user.role == ROLE_TEACHER:
        assignment = db.query(Assignment).filter(Assignment.id == assignment_id, Assignment.teacher_id == user.id).first()
        if not assignment:
            raise HTTPException(status_code=403, detail="Not your assignment")
    return q.order_by(Submission.uploaded_at.desc()).all()

@router.get("/{submission_id}/download")
def download_submission(submission_id: int, db: Session = Depends(get_db), teacher: User = Depends(require_role(ROLE_TEACHER))):
    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Not found")
    assignment = db.query(Assignment).filter(Assignment.id == submission.assignment_id, Assignment.teacher_id == teacher.id).first()
    if not assignment:
        raise HTTPException(status_code=403, detail="Not your assignment")
    path = os.path.join(SUBMIT_DIR, submission.file_name)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="File missing")
    with open(path, 'rb') as f:
        return {"filename": submission.file_name, "content": f.read().decode('latin-1')}  # naive representation

@router.post("/{submission_id}/grade", response_model=SubmissionRead)
def grade_submission(submission_id: int, payload: GradeSubmission, db: Session = Depends(get_db), teacher: User = Depends(require_role(ROLE_TEACHER))):
    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Not found")
    assignment = db.query(Assignment).filter(Assignment.id == submission.assignment_id, Assignment.teacher_id == teacher.id).first()
    if not assignment:
        raise HTTPException(status_code=403, detail="Not your assignment")
    submission.grade = payload.grade
    submission.comment = payload.comment
    submission.graded_at = datetime.utcnow()
    db.commit()
    db.refresh(submission)
    return submission
