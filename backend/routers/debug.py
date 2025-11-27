from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import CourseStudent, Course, User
from ..deps import get_current_user
import os
from ..database import DATABASE_URL

router = APIRouter(prefix="/debug", tags=["debug"])


@router.get("/me")
def whoami(user: User = Depends(get_current_user)):
    return {"id": user.id, "email": user.email, "role": user.role, "name": user.name}


@router.get("/course/{course_id}/students")
def list_course_students(course_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    # allow teachers and students to inspect for debugging
    rows = db.query(CourseStudent).filter(CourseStudent.course_id == course_id).all()
    return [{"id": r.id, "course_id": r.course_id, "student_id": r.student_id} for r in rows]


@router.get("/student/{student_id}/courses")
def list_student_courses(student_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    rows = db.query(CourseStudent).filter(CourseStudent.student_id == student_id).all()
    course_ids = [r.course_id for r in rows]
    courses = db.query(Course).filter(Course.id.in_(course_ids)).all() if course_ids else []
    return [{"id": c.id, "name": c.name, "teacher_id": c.teacher_id} for c in courses]


@router.get("/dbinfo")
def db_info():
    info = {"DATABASE_URL": DATABASE_URL}
    # if using sqlite, try to resolve path
    if DATABASE_URL.startswith("sqlite"):
        # sqlite:///./backend.db or sqlite:////absolute/path
        path = DATABASE_URL.split("sqlite:", 1)[1]
        # strip leading ///
        path = path.lstrip('/')
        info["sqlite_path"] = os.path.abspath(path)
    return info
