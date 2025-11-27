from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import Course, User, CourseStudent, ROLE_TEACHER, ROLE_STUDENT
from ..schemas import CourseCreate, CourseRead, CourseStudentAdd
from ..deps import get_current_user, require_role

router = APIRouter(prefix="/courses", tags=["courses"])

@router.post("/", response_model=CourseRead)
def create_course(data: CourseCreate, db: Session = Depends(get_db), teacher: User = Depends(require_role(ROLE_TEACHER))):
    course = Course(name=data.name, teacher_id=teacher.id)
    db.add(course)
    db.commit()
    db.refresh(course)
    return course

@router.get("/", response_model=list[CourseRead])
def list_courses(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if user.role == ROLE_TEACHER:
        return db.query(Course).filter(Course.teacher_id == user.id).all()
    elif user.role == ROLE_STUDENT:
        return [cs.course for cs in db.query(CourseStudent).filter(CourseStudent.student_id == user.id).all()]
    else:
        return db.query(Course).all()

@router.post("/{course_id}/students")
def add_student(course_id: int, payload: CourseStudentAdd, db: Session = Depends(get_db), teacher: User = Depends(require_role(ROLE_TEACHER))):
    course = db.query(Course).filter(Course.id == course_id, Course.teacher_id == teacher.id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Course not found or not owned")
    student = db.query(User).filter(User.id == payload.student_id, User.role == ROLE_STUDENT).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    existing = db.query(CourseStudent).filter(CourseStudent.course_id == course.id, CourseStudent.student_id == student.id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Student already enrolled")
    link = CourseStudent(course_id=course.id, student_id=student.id)
    db.add(link)
    db.commit()
    return {"message": "Student added"}
