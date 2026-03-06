CREATE DATABASE ADM
ON
PRIMARY (
    NAME = AMD_Data,
    FILENAME = 'E:\My Files\ITI\Projects\SQL Project/ADM_Data.mdf',
    SIZE = 100MB,
    FILEGROWTH = 10MB
),
FILEGROUP FG_Transactions (
    NAME = ADM_Trans,
    FILENAME = 'E:\My Files\ITI\Projects\SQL Project/ADM_Trans.ndf',
    SIZE = 200MB,
    FILEGROWTH = 20MB
)
LOG ON (
    NAME = ADM_Log,
    FILENAME = 'E:\My Files\ITI\Projects\SQL Project/ADM_Log.ldf',
    SIZE = 50MB,
    FILEGROWTH = 10MB
);
SELECT name 
FROM sys.databases 
WHERE name = 'ADM';

ALTER DATABASE ADM SET RECOVERY SIMPLE;
ALTER DATABASE ADM SET AUTO_CLOSE OFF;
ALTER DATABASE ADM SET AUTO_UPDATE_STATISTICS ON;

use ADM;

CREATE TABLE Department (
    DepartmentID INT IDENTITY PRIMARY KEY,
    DepartmentName NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(255)
);


CREATE TABLE Branch (
    BranchID INT IDENTITY PRIMARY KEY,
    BranchName NVARCHAR(100) NOT NULL,
    Location NVARCHAR(100)
);

CREATE TABLE Track (
    TrackID INT IDENTITY PRIMARY KEY,
    TrackName NVARCHAR(100) NOT NULL,
    DepartmentID INT NOT NULL,
    FOREIGN KEY (DepartmentID) REFERENCES Department(DepartmentID)
);

CREATE TABLE Intake (
    IntakeID INT IDENTITY PRIMARY KEY,
    IntakeYear INT NOT NULL,
    StartDate DATE,
    EndDate DATE
);
CREATE TABLE Instructor (
    InstructorID INT IDENTITY PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) UNIQUE,
    Phone NVARCHAR(20),
    IsTrainingManager BIT DEFAULT 0
);

CREATE TABLE Student (
    StudentID INT IDENTITY PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) UNIQUE,
    Phone NVARCHAR(20),
    BranchID INT,
    TrackID INT,
    IntakeID INT,
    FOREIGN KEY (BranchID) REFERENCES Branch(BranchID),
    FOREIGN KEY (TrackID) REFERENCES Track(TrackID),
    FOREIGN KEY (IntakeID) REFERENCES Intake(IntakeID)
);
CREATE TABLE Course (
    CourseID INT IDENTITY PRIMARY KEY,
    CourseName NVARCHAR(100) NOT NULL,
    Description NVARCHAR(255),
    MaxDegree INT NOT NULL,
    MinDegree INT NOT NULL
);

CREATE TABLE CourseOffering (
    CourseOfferingID INT IDENTITY PRIMARY KEY,
    CourseID INT NOT NULL,
    InstructorID INT NOT NULL,
    IntakeID INT NOT NULL,
    BranchID INT NOT NULL,
    TrackID INT NOT NULL,
    AcademicYear INT NOT NULL,
    FOREIGN KEY (CourseID) REFERENCES Course(CourseID),
    FOREIGN KEY (InstructorID) REFERENCES Instructor(InstructorID),
    FOREIGN KEY (IntakeID) REFERENCES Intake(IntakeID),
    FOREIGN KEY (BranchID) REFERENCES Branch(BranchID),
    FOREIGN KEY (TrackID) REFERENCES Track(TrackID)
);

CREATE TABLE Question (
    QuestionID INT IDENTITY PRIMARY KEY,
    CourseID INT NOT NULL,
    QuestionType VARCHAR(20) CHECK (QuestionType IN ('MCQ','TrueFalse','Text')),
    QuestionText NVARCHAR(MAX) NOT NULL,
    CorrectAnswer NVARCHAR(255),          -- MCQ & True/False
    BestAcceptedAnswer NVARCHAR(MAX),     -- Text questions
    FOREIGN KEY (CourseID) REFERENCES Course(CourseID)
);

CREATE TABLE QuestionChoice (
    ChoiceID INT IDENTITY PRIMARY KEY,
    QuestionID INT NOT NULL,
    ChoiceText NVARCHAR(255) NOT NULL,
    IsCorrect BIT DEFAULT 0,
    FOREIGN KEY (QuestionID) REFERENCES Question(QuestionID)
);
CREATE TABLE Exam (
    ExamID INT IDENTITY PRIMARY KEY,
    CourseOfferingID INT NOT NULL,
    ExamType VARCHAR(20) CHECK (ExamType IN ('Exam','Corrective')),
    StartDateTime DATETIME NOT NULL,
    EndDateTime DATETIME NOT NULL,
    DurationMinutes INT NOT NULL,
    TotalDegree INT NOT NULL,
    AllowBacktracking BIT DEFAULT 1,
    FOREIGN KEY (CourseOfferingID) REFERENCES CourseOffering(CourseOfferingID)
);

CREATE TABLE ExamQuestion (
    ExamQuestionID INT IDENTITY PRIMARY KEY,
    ExamID INT NOT NULL,
    QuestionID INT NOT NULL,
    QuestionDegree INT NOT NULL,
    FOREIGN KEY (ExamID) REFERENCES Exam(ExamID),
    FOREIGN KEY (QuestionID) REFERENCES Question(QuestionID),
);

CREATE TABLE ExamStudent (
    ExamStudentID INT IDENTITY PRIMARY KEY,
    ExamID INT NOT NULL,
    StudentID INT NOT NULL,
    FOREIGN KEY (ExamID) REFERENCES Exam(ExamID),
    FOREIGN KEY (StudentID) REFERENCES Student(StudentID)
);
CREATE TABLE StudentAnswer (
    StudentAnswerID INT IDENTITY PRIMARY KEY,
    ExamID INT NOT NULL,
    QuestionID INT NOT NULL,
    StudentID INT NOT NULL,
    AnswerText NVARCHAR(MAX),
    IsCorrect BIT,
    AutoDegree INT,
    ManualDegree INT,
    FOREIGN KEY (ExamID) REFERENCES Exam(ExamID),
    FOREIGN KEY (QuestionID) REFERENCES Question(QuestionID),
    FOREIGN KEY (StudentID) REFERENCES Student(StudentID)
);

CREATE TABLE StudentCourseResult (
    ResultID INT IDENTITY PRIMARY KEY,
    StudentID INT NOT NULL,
    CourseOfferingID INT NOT NULL,
    FinalDegree INT,
    ResultStatus VARCHAR(10) CHECK (ResultStatus IN ('Pass','Fail')),
    FOREIGN KEY (StudentID) REFERENCES Student(StudentID),
    FOREIGN KEY (CourseOfferingID) REFERENCES CourseOffering(CourseOfferingID)
);

backup database [ADM]to disk ='E:\My Files\ITI\Projects\SQL Project/ADM.bak';

Alter TABLE ExamStudent
Add CONSTRAINT UQ_ExamStudent_Student_Exam
    UNIQUE (StudentID,ExamID);

ALTER TABLE ExamStudent
ADD
    StartTime DATETIME NULL,
    EndTime DATETIME NULL,
    FinalScore DECIMAL(5,2) NULL,
    AttemptStatus VARCHAR(20) DEFAULT 'NotStarted';


--------------------Procedures------------------------
create procedure startExam
@StudentID INT, @ExamID INT
as
begin
    set nocount on;

    if exists(
        select 1 from ExamStudent where StudentID=@StudentID
                                  AND ExamID=@ExamID
    )
    Begin
        Raiserror ('The Student already took this Exam',16,1);
        return ;
    end
    insert into  ExamStudent(examid, studentid,startTime)
    values (@ExamID,@StudentID,GETDATE());
end;





CREATE PROCEDURE GradeExamStudent
    @ExamID INT,
    @StudentID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalScore DECIMAL(5,2) = 0;

    UPDATE sa
    SET
        sa.IsCorrect = CASE
                          WHEN sa.AnswerText = q.CorrectAnswer THEN 1
                          ELSE 0
                       END,
        sa.AutoDegree = CASE
                          WHEN sa.AnswerText = q.CorrectAnswer
                          THEN eq.QuestionDegree
                          ELSE 0
                        END
    FROM StudentAnswer sa
    JOIN Question q
        ON sa.QuestionID = q.QuestionID
    JOIN ExamQuestion eq
        ON eq.QuestionID = sa.QuestionID
       AND eq.ExamID = sa.ExamID
    WHERE sa.ExamID = @ExamID
      AND sa.StudentID = @StudentID
      AND q.QuestionType IN ('MCQ','TrueFalse');

    SELECT @TotalScore =
           SUM(ISNULL(AutoDegree,0) + ISNULL(ManualDegree,0))
    FROM StudentAnswer
    WHERE ExamID = @ExamID
      AND StudentID = @StudentID;

    UPDATE ExamStudent
    SET
        FinalScore = @TotalScore,
        EndTime = GETDATE(),
        AttemptStatus = 'Completed'
    WHERE ExamID = @ExamID
      AND StudentID = @StudentID;
END;











CREATE PROCEDURE GradeTextAnswer
    @ExamID INT,
    @StudentID INT,
    @QuestionID INT,
    @Score INT
AS
BEGIN
    UPDATE StudentAnswer
    SET ManualDegree = @Score
    WHERE ExamID=@ExamID
      AND StudentID=@StudentID
      AND QuestionID=@QuestionID;
END;

CREATE  PROCEDURE CalculateFinalResult
    @StudentID INT,
    @ExamID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @FinalScore DECIMAL(5,2),
        @CourseOfferingID INT,
        @MinDegree INT,
        @ResultStatus VARCHAR(10);

    SELECT @FinalScore = FinalScore
    FROM ExamStudent
    WHERE StudentID = @StudentID
      AND ExamID = @ExamID;

    IF @FinalScore IS NULL
    BEGIN
        RAISERROR ('Exam is not graded yet',16,1);
        RETURN;
    END

    SELECT @CourseOfferingID = CourseOfferingID
    FROM Exam
    WHERE ExamID = @ExamID;

    SELECT @MinDegree = c.MinDegree
    FROM CourseOffering co
    JOIN Course c ON co.CourseID = c.CourseID
    WHERE co.CourseOfferingID = @CourseOfferingID;

    /* Determine pass/fail */
    SET @ResultStatus =
        CASE
            WHEN @FinalScore >= @MinDegree THEN 'Pass'
            ELSE 'Fail'
        END;

    IF EXISTS (
        SELECT 1
        FROM StudentCourseResult
        WHERE StudentID = @StudentID
          AND CourseOfferingID = @CourseOfferingID
    )
    BEGIN
        UPDATE StudentCourseResult
        SET
            FinalDegree = @FinalScore,
            ResultStatus = @ResultStatus
        WHERE StudentID = @StudentID
          AND CourseOfferingID = @CourseOfferingID;
    END
    ELSE
    BEGIN
        INSERT INTO StudentCourseResult
            (StudentID, CourseOfferingID, FinalDegree, ResultStatus)
        VALUES
            (@StudentID, @CourseOfferingID, @FinalScore, @ResultStatus);
    END
END;


CREATE TRIGGER trg_AfterExamStudentUpdate
ON ExamStudent
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ExamID INT, @StudentID INT;
    SELECT @ExamID = ExamID, @StudentID = StudentID FROM inserted;

    EXEC CalculateFinalResult @StudentID, @ExamID;
END;


---------------Views------------------
CREATE VIEW VW_Instructor_Exam_Results
AS
SELECT
    i.InstructorID,
    i.FullName AS InstructorName,
    s.StudentID,
    s.FullName AS StudentName,
    c.CourseName,
    e.ExamID,
    es.FinalScore,
    es.AttemptStatus
FROM ExamStudent es
JOIN Student s ON es.StudentID = s.StudentID
JOIN Exam e ON es.ExamID = e.ExamID
JOIN CourseOffering co ON e.CourseOfferingID = co.CourseOfferingID
JOIN Course c ON co.CourseID = c.CourseID
JOIN Instructor i ON co.InstructorID = i.InstructorID;

CREATE VIEW VW_Student_Results
AS
SELECT
    s.StudentID,
    s.FullName AS StudentName,
    c.CourseName,
    scr.FinalDegree,
    scr.ResultStatus
FROM StudentCourseResult scr
JOIN Student s ON scr.StudentID = s.StudentID
JOIN CourseOffering co ON scr.CourseOfferingID = co.CourseOfferingID
JOIN Course c ON co.CourseID = c.CourseID;


CREATE VIEW VW_Course_Statistics
AS
SELECT
    c.CourseName,
    COUNT(scr.StudentID) AS TotalStudents,
    SUM(CASE WHEN scr.ResultStatus = 'Pass' THEN 1 ELSE 0 END) AS PassedStudents,
    SUM(CASE WHEN scr.ResultStatus = 'Fail' THEN 1 ELSE 0 END) AS FailedStudents,
    AVG(CAST(scr.FinalDegree AS FLOAT)) AS AverageDegree
FROM StudentCourseResult scr
JOIN CourseOffering co ON scr.CourseOfferingID = co.CourseOfferingID
JOIN Course c ON co.CourseID = c.CourseID
GROUP BY c.CourseName;



----------Indexes--------------
CREATE NONCLUSTERED INDEX IDX_ExamStudent_ExamID
ON ExamStudent(ExamID);

CREATE NONCLUSTERED INDEX IDX_StudentAnswer_Exam_Student
ON StudentAnswer(ExamID, StudentID);

CREATE NONCLUSTERED INDEX IDX_StudentAnswer_QuestionID
ON StudentAnswer(QuestionID);

CREATE NONCLUSTERED INDEX IDX_ExamQuestion_ExamID
ON ExamQuestion(ExamID);

CREATE NONCLUSTERED INDEX IDX_ExamQuestion_QuestionID
ON ExamQuestion(QuestionID);

CREATE NONCLUSTERED INDEX IDX_Question_CourseID
ON Question(CourseID);

CREATE NONCLUSTERED INDEX IDX_Question_Type
ON Question(QuestionType);

CREATE NONCLUSTERED INDEX IDX_CourseOffering_InstructorID
ON CourseOffering(InstructorID);

CREATE NONCLUSTERED INDEX IDX_CourseOffering_CourseID
ON CourseOffering(CourseID);

SELECT *
FROM sys.dm_db_index_usage_stats
WHERE database_id = DB_ID('ADM');