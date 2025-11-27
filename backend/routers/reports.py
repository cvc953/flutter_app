from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import User, Submission, Assignment, CourseStudent, ParentChild, ROLE_STUDENT, ROLE_TEACHER, ROLE_PARENT
from ..schemas import StudentReport, AssignmentReportItem
from ..deps import get_current_user

router = APIRouter(prefix="/reports", tags=["reports"])

@router.get("/me", response_model=StudentReport)
def my_report(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if user.role == ROLE_STUDENT:
        return _build_student_report(db, user)
    elif user.role == ROLE_PARENT:
        # choose first child for simplicity
        link = db.query(ParentChild).filter(ParentChild.parent_id == user.id).first()
        if not link:
            raise HTTPException(status_code=404, detail="No child linked")
        student = db.query(User).filter(User.id == link.child_id).first()
        return _build_student_report(db, student)
    else:  # teacher - aggregate own students maybe out of scope -> return empty
        raise HTTPException(status_code=400, detail="Use /reports/student/{id} for student reports")

@router.get("/student/{student_id}", response_model=StudentReport)
def student_report(student_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    target = db.query(User).filter(User.id == student_id, User.role == ROLE_STUDENT).first()
    if not target:
        raise HTTPException(status_code=404, detail="Student not found")
    # authorization: teacher of any course of student or parent of student or the student themselves
    if user.role == ROLE_STUDENT and user.id != target.id:
        raise HTTPException(status_code=403, detail="Not allowed")
    if user.role == ROLE_PARENT:
        link = db.query(ParentChild).filter(ParentChild.parent_id == user.id, ParentChild.child_id == target.id).first()
        if not link:
            raise HTTPException(status_code=403, detail="Not linked to this student")
    if user.role == ROLE_TEACHER:
        course_link = db.query(CourseStudent).join(Assignment, Assignment.course_id == CourseStudent.course_id).filter(CourseStudent.student_id == target.id, Assignment.teacher_id == user.id).first()
        if not course_link:
            raise HTTPException(status_code=403, detail="Not teacher of this student")
    return _build_student_report(db, target)

def _build_student_report(db: Session, student: User) -> StudentReport:
    submissions = db.query(Submission).filter(Submission.student_id == student.id).all()
    latest_by_assignment = {}
    for s in sorted(submissions, key=lambda x: x.uploaded_at):
        latest_by_assignment[s.assignment_id] = s
    items: list[AssignmentReportItem] = []
    for assignment_id, sub in latest_by_assignment.items():
        assignment = db.query(Assignment).filter(Assignment.id == assignment_id).first()
        if not assignment:
            continue
        items.append(AssignmentReportItem(
            assignment_id=assignment.id,
            title=assignment.title,
            latest_grade=sub.grade,
            due_date=assignment.due_date,
            last_submission_at=sub.uploaded_at
        ))
    return StudentReport(student_id=student.id, student_name=student.name, assignments=items)
