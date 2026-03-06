
--=========================================Test data ===================

-- Users
INSERT INTO [User] (Username, Email, PasswordHash, Role)
VALUES
('admin1','admin1@test.com','hashedpwd1','Admin'),
('manager1','manager1@test.com','hashedpwd2','TrainingManager'),
('instructor1','instructor1@test.com','hashedpwd3','Instructor'),
('student1','student1@test.com','hashedpwd4','Student'),
('student2','student2@test.com','hashedpwd5','Student');


--------------------------
-- Departments
INSERT INTO Department (DepartmentName, Description)
VALUES
('Computer Science','CS Dept'),
('Information Systems','IS Dept');

--------------------------
-- Branches
INSERT INTO Branch (BranchName, Location)
VALUES
('Main Branch','Cairo'),
('Branch B','Alexandria');

--------------------------
-- Tracks
INSERT INTO Track (TrackName, DepartmentID)
VALUES
('AI Track',1),
('DB Track',1),
('Networking Track',2);

--------------------------
-- Intakes
INSERT INTO Intake (IntakeYear, StartDate, EndDate, IntakeName)
VALUES
(2026,'2026-01-01','2026-06-30','Jan 2026 Intake'),
(2026,'2026-07-01','2026-12-31','Jul 2026 Intake');

--------------------------
-- Instructors
INSERT INTO Instructor (FullName, Email, Phone, UserID)
VALUES
('John Doe','john@test.com','0123456789',3);

--------------------------
-- Students
INSERT INTO Student (FullName, Email, Phone, BranchID, TrackID, IntakeID, UserID)
VALUES
('Alice Smith','alice@test.com','010111222',1,1,1,4),
('Bob Brown','bob@test.com','010333444',2,3,2,5);

--------------------------
-- Courses
INSERT INTO Course (CourseName, Description, MaxDegree, MinDegree)
VALUES
('SQL Basics','Intro to SQL',100,50),
('Python Programming','Python 101',100,50);

--------------------------
-- Course Offerings
INSERT INTO CourseOffering (CourseID, InstructorID, IntakeID, BranchID, TrackID, AcademicYear)
VALUES
(1,1,1,1,1,2026),
(2,1,2,2,3,2026);
--------------------------
-- Question Types
INSERT INTO Question_Type (code, [description])
VALUES
('MCQ','Multiple Choice Question'),
('TF','True/False Question'),
('TEXT','Text / Essay Question');


--------------------------
-- Question Pools
INSERT INTO Question_Pool (course_id, instructor_id, title, [description])
VALUES
(1,1,'SQL Pool','Pool of SQL Questions');

--------------------------
-- Questions
INSERT INTO Question
(CourseID, QuestionType, QuestionText, CorrectAnswer, pool_id, instructor_id, question_type_id, is_active)
VALUES
    (1, 'MCQ', 'What is SQL?', 'Structured Query Language', 1, 1, 1, 1), 
    (1, 'TrueFalse', 'SQL is case sensitive?' , 'False', 1, 1, 2, 1),
    (2, 'Text', 'Explain Python functions', NULL, NULL, 1, 3, 1);

--------------------------
-- Question Choices
INSERT INTO QuestionChoice (QuestionID, ChoiceText, [is_correct], display_order)
VALUES
(1,'Structured Query Language',1,1),
(1,'Simple Query Language',0,2),
(2,'True',0,1),
(2,'False',1,2);


--------------------------
-- Exams
INSERT INTO Exam (CourseOfferingID, ExamType, Title, StartDateTime, EndDateTime, DurationMinutes, TotalDegree, AllowBacktracking)
VALUES
(1,'Exam','SQL Midterm','2026-03-10 09:00','2026-03-10 11:00',120,100,1),
(2,'Exam','Python Final','2026-06-10 13:00','2026-06-10 15:00',120,100,1);

--------------------------
-- Exam Questions
INSERT INTO ExamQuestion (ExamID, QuestionID, QuestionDegree, display_order)
VALUES
(1,1,50,1),
(1,2,50,2),
(2,3,100,1);

--------------------------
-- Exam Eligibility
INSERT INTO EXAM_ELIGIBILITY (exam_id, student_id, scheduled_start, scheduled_end)
VALUES
(1,1,'2026-03-10 09:00','2026-03-10 11:00'),
(1,2,'2026-03-10 09:00','2026-03-10 11:00'),
(2,1,'2026-06-10 13:00','2026-06-10 15:00');



-----Views
-- Student & Instructor Views
SELECT * FROM vw_StudentsFullInfo;
SELECT * FROM vw_StudentsPerIntake;
SELECT * FROM vw_InstructorCourses;
SELECT * FROM vw_CoursesPerInstructor;
SELECT * FROM vw_ClassOfferings;

-- Exam & Question Views
SELECT * FROM VW_Questions_Details;
SELECT * FROM VW_Exam_Questions;
SELECT * FROM VW_Question_Choices;
SELECT * FROM VW_Student_Eligible_Exams;
SELECT * FROM VW_Exam_Full_Details;
SELECT * FROM VW_QuestionPool_Stats;

-- Results Views
SELECT * FROM VW_Instructor_Exam_Results;
SELECT * FROM VW_Student_Results;
SELECT * FROM VW_Course_Statistics;



---=================Procedures===============

-- Users
EXEC sp_CreateUser 'admin2','admin2@test.com','hashedpwd','Admin';
EXEC sp_CreateUser 'student3','student3@test.com','hashedpwd','Student';
select * from [User]
-- Instructors
EXEC sp_CreateInstructor 6,'Jane Doe','jane@test.com','0123456789';

-- Students
EXEC sp_CreateStudent 7,'Charlie Brown','charlie@test.com','010999888',1,1,1;

-- Courses
EXEC sp_CreateCourse 'C# Programming','Learn C#',100,50;

-- Class Offerings
EXEC sp_CreateClassOffering 1,3,1,1,1,2026;

-- Question Pool
INSERT INTO Question_Pool(course_id, instructor_id, title)
VALUES(1,1,'C# Pool');

-- Questions & Choices
INSERT INTO Question(CourseID, pool_id, instructor_id, question_type_id, QuestionText, CorrectAnswer)
VALUES(1,1,1,1,'What is C#?','Programming Language');
EXEC sp_AddQuestionChoice 1,'Programming Language',1,1;
EXEC sp_AddQuestionChoice 1,'Cooking Ingredient',0,2;

-- Exams
EXEC sp_CreateExam 1,'Exam','Midterm','C# Midterm','2026-03-10 09:00','2026-03-10 11:00',120,100,1;

-- Add Question to Exam
EXEC sp_AddQuestionToExam 1,1,100,1;

-- Exam Eligibility
EXEC sp_AddExamEligibility 1,1,'2026-03-10 09:00','2026-03-10 11:00';

-- Start Exam
EXEC startExam 1,1;

-- Grade Exam
EXEC GradeExamStudent 1,1;

-- Grade Text Answer (manual)
EXEC GradeTextAnswer 2,1,3,100;

-- Calculate Final Result
EXEC CalculateFinalResult 1,1;

--==========================Test result and comment===========















