from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr

# User schemas
class UserBase(BaseModel):
    name: str
    email: EmailStr
    role: str

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: str

class UserRead(UserBase):
    id: int
    class Config:
        from_attributes = True

# Course schemas
class CourseBase(BaseModel):
    name: str

class CourseCreate(CourseBase):
    pass

class CourseRead(CourseBase):
    id: int
    teacher_id: int
    class Config:
        from_attributes = True

class CourseStudentAdd(BaseModel):
    student_id: int

# Parent-child link
class ParentChildCreate(BaseModel):
    parent_id: int
    child_id: int

# Assignment schemas
class AssignmentBase(BaseModel):
    title: str
    description: Optional[str] = None
    due_date: datetime

class AssignmentCreate(AssignmentBase):
    pass

class AssignmentRead(AssignmentBase):
    id: int
    course_id: int
    teacher_id: int
    attachment_filename: Optional[str]
    created_at: datetime
    class Config:
        from_attributes = True

# Submission schemas
class SubmissionRead(BaseModel):
    id: int
    assignment_id: int
    student_id: int
    uploaded_at: datetime
    file_name: str
    grade: Optional[int]
    comment: Optional[str]
    graded_at: Optional[datetime]
    class Config:
        from_attributes = True

class GradeSubmission(BaseModel):
    grade: int
    comment: Optional[str] = None

# Report schemas
class AssignmentReportItem(BaseModel):
    assignment_id: int
    title: str
    latest_grade: Optional[int]
    due_date: datetime
    last_submission_at: Optional[datetime]

class StudentReport(BaseModel):
    student_id: int
    student_name: str
    assignments: List[AssignmentReportItem]
