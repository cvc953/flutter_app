from fastapi import FastAPI
from .database import engine, Base
from .routers import auth, courses, assignments, submissions, reports
import os

# create tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Education Tasks API", version="0.1.0")

# include routers
app.include_router(auth.router)
app.include_router(courses.router)
app.include_router(assignments.router)
app.include_router(submissions.router)
app.include_router(reports.router)

@app.get("/")
def root():
    return {"message": "API running"}

# ensure storage subfolders
for folder in ["backend/storage/assignments", "backend/storage/submissions"]:
    os.makedirs(folder, exist_ok=True)
