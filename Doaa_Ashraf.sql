CREATE TABLE [User] (
    UserID       INT IDENTITY(1,1) PRIMARY KEY,
    Username     NVARCHAR(100) NOT NULL,
    Email        NVARCHAR(255) NOT NULL,
    PasswordHash NVARCHAR(256) NOT NULL,
    Role         NVARCHAR(20) NOT NULL,  
    CreatedAt    DATETIME2 NOT NULL DEFAULT GetDate(),
    IsActive     BIT NOT NULL DEFAULT(1)
);

---------
ALTER TABLE Instructor
add UserID INT NOT NULL

ALTER TABLE Instructor
ADD CONSTRAINT FK_Instructor_User 
FOREIGN KEY (UserID) REFERENCES [User](UserID);


ALTER TABLE Instructor
ADD CONSTRAINT UQ_Instructor_User UNIQUE (UserID) 
---

ALTER TABLE [dbo].[Student]
add UserID INT NOT NULL


ALTER TABLE [dbo].[Student]
ADD CONSTRAINT UQ_Student_User UNIQUE (UserID) 

ALTER TABLE Student
ADD CONSTRAINT UQ_Student_Intake
UNIQUE (FullName, IntakeID)

ALTER TABLE [dbo].[Student]
ADD CONSTRAINT FK_Student_User 
FOREIGN KEY (UserID) REFERENCES [User](UserID) ;


CREATE INDEX IX_Student_FullName ON Student(FullName);
----
CREATE UNIQUE INDEX UX_User_Username ON [User](username);
CREATE UNIQUE INDEX UX_User_Email ON [User](email);
-----
ALTER TABLE [User]
ADD CONSTRAINT CK_User_Role CHECK (Role IN ('Admin','TrainingManager','Instructor','Student'));
----
ALTER TABLE [dbo].[Intake]
ADD IntakeName NVARCHAR(100) NOT NULL
---
ALTER TABLE Intake
ADD CONSTRAINT CK_Intake_Dates
CHECK (EndDate > StartDate)
----
ALTER TABLE Course
ADD CONSTRAINT CK_Course_Degree
CHECK ([MinDegree] <=[MaxDegree]  AND [MinDegree] >= 0);
-- index for search (non-clustered)
CREATE INDEX IX_Course_CourseName ON Course(CourseName);
------
CREATE UNIQUE INDEX UX_ClassOffering_Unique ON [dbo].[CourseOffering](
    CourseID, InstructorID, IntakeID, BranchID, TrackID,[AcademicYear] 
);


--===========PROCEDURES============

---create account
create PROCEDURE sp_CreateUser
    @Username NVARCHAR(100),
    @Email NVARCHAR(255),
    @PasswordHash NVARCHAR(256),
    @Role NVARCHAR(20)
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO [User](Username, Email, PasswordHash, Role)
        VALUES(@Username, @Email, @PasswordHash, @Role);
        print 'User Created Successfully'
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
          ROLLBACK TRANSACTION;
         DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50000, @ErrMsg, 1;
    END CATCH
END
GO

--enter data to table instructor
create PROCEDURE sp_CreateInstructor
    @UserID INT,
    @FullName NVARCHAR(200),
    @Email NVARCHAR(100),
    @Phone NVARCHAR(50) = NULL
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- validation: user exists and role correct
        IF NOT EXISTS (SELECT 1 FROM [User] WHERE UserID = @UserID AND Role IN ('Instructor','TrainingManager','Admin'))
            THROW 51000, 'User not found or role not allowed to be an instructor.', 1;

        INSERT INTO Instructor(FullName,Email, Phone,UserID)
        VALUES(@FullName,@Email, @Phone,@UserID);
        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
          ROLLBACK TRANSACTION;
          DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50000, @ErrMsg, 1;
        
    END CATCH
END
GO
--
----------
--add student
create PROCEDURE sp_CreateStudent
    @UserID INT,
    @FullName NVARCHAR(200),
    @Email NVARCHAR(255) = NULL,
    @Phone NVARCHAR(50) = NULL,
    @BranchID INT = NULL,
    @TrackID INT = NULL,
    @IntakeID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM [User] WHERE UserID = @UserID AND Role = 'Student')
            THROW 52000, 'User not found or role is not Student.', 1;

        INSERT INTO Student(UserID, FullName, Email, Phone, BranchID, TrackID, IntakeID)
        VALUES(@UserID, @FullName, @Email, @Phone, @BranchID, @TrackID, @IntakeID);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
          ROLLBACK TRANSACTION;
          DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
          THROW 50000, @ErrMsg, 1;
    END CATCH
END
GO
-----
--add course
create PROCEDURE sp_CreateCourse
    @CourseName NVARCHAR(200),
    @Description NVARCHAR(1000) = NULL,
    @MaxDegree INT = 100,
    @MinDegree INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO Course(CourseName, Description, MaxDegree, MinDegree)
        VALUES(@CourseName, @Description, @MaxDegree, @MinDegree);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
          ROLLBACK TRANSACTION;
          DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
          THROW 50000, @ErrMsg, 1;
    END CATCH
END
GO
--add Class Offering
create PROCEDURE sp_CreateClassOffering
    @CourseID INT,
    @InstructorID INT,
    @IntakeID INT,
    @BranchID INT,
    @TrackID INT = NULL,
    @Year INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Basic existence checks
        IF NOT EXISTS (SELECT 1 FROM  Course WHERE CourseID = @CourseID) 
                THROW 53001, 'Course not found.', 1;

        IF NOT EXISTS (SELECT 1 FROM Instructor WHERE InstructorID = @InstructorID) 
                THROW 53002, 'Instructor not found.', 1;

        IF NOT EXISTS (SELECT 1 FROM  Intake WHERE IntakeID = @IntakeID) THROW 53003, 'Intake not found.', 1;
        IF NOT EXISTS (SELECT 1 FROM  Branch WHERE BranchID = @BranchID) THROW 53004, 'Branch not found.', 1;
        IF @TrackID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM  Track WHERE TrackID = @TrackID)
                THROW 53005, 'Track not found.', 1;

        IF EXISTS (
            SELECT 1 FROM [dbo].[CourseOffering]
            WHERE CourseID=@CourseID AND InstructorID=@InstructorID AND IntakeID=@IntakeID
              AND BranchID=@BranchID AND ISNULL(TrackID, -1) = ISNULL(@TrackID, -1)
              AND [AcademicYear]=@Year 
        ) THROW 53006, 'Duplicate class offering.', 1;

        INSERT INTO  [dbo].[CourseOffering](CourseID, InstructorID, IntakeID, BranchID, TrackID, AcademicYear)
        VALUES(@CourseID, @InstructorID, @IntakeID, @BranchID, @TrackID, @Year);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50000, @ErrMsg, 1;
    END CATCH
END
GO
-------
CREATE PROCEDURE usp_SearchStudents
    @Name NVARCHAR(100) = NULL,
    @BranchName INT = NULL
AS
BEGIN
    SELECT *
    FROM vw_StudentsFullInfo
    WHERE (@Name IS NULL OR FullName LIKE '%' + @Name + '%')
      AND (@BranchName IS NULL OR BranchName = @BranchName)
END

---
CREATE PROCEDURE UpdateDepartment
    @DepartmentID INT,
    @DepartmentName VARCHAR(100)
AS
BEGIN
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Department WHERE DepartmentID = @DepartmentID)
        BEGIN
            THROW 50002, 'Department not found.', 1;
        END

        UPDATE Department
        SET DepartmentName = @DepartmentName
        WHERE DepartmentID = @DepartmentID;

    END TRY

    BEGIN CATCH
        THROW;
    END CATCH
END
GO



---==================Views==================

CREATE VIEW vw_StudentsFullInfo
AS
SELECT 
    s.StudentID,
    s.FullName,
    b.BranchName,
    t.TrackName,
    i.IntakeName
FROM Student s
LEFT JOIN Branch b ON s.BranchID = b.BranchID
LEFT JOIN Track t ON s.TrackID = t.TrackID
LEFT JOIN Intake i ON s.IntakeID = i.IntakeID;
------

CREATE VIEW vw_InstructorCourses
AS
SELECT 
    ins.InstructorID,
    ins.FullName,
    c.CourseName,
    co.AcademicYear
FROM CourseOffering co
JOIN Instructor ins ON co.InstructorID = ins.InstructorID
JOIN Course c ON co.CourseID = c.CourseID;

----------------


--View Students per Intake

CREATE VIEW vw_StudentsPerIntake
AS
SELECT 
    i.IntakeID,
    i.IntakeName,
    s.StudentID,
    s.FullName,
    b.BranchName,
    t.TrackName
FROM Student s
JOIN Intake i ON s.IntakeID = i.IntakeID
LEFT JOIN Branch b ON s.BranchID = b.BranchID
LEFT JOIN Track t ON s.TrackID = t.TrackID;
GO
-------

--View Courses per Instructor
-- What does each Instructor teach?
CREATE VIEW vw_CoursesPerInstructor
AS
SELECT 
    ins.InstructorID,
    ins.FullName,
    c.CourseName,
    co.AcademicYear,
    b.BranchName,
    i.IntakeName
FROM CourseOffering co
JOIN Instructor ins ON co.InstructorID = ins.InstructorID
JOIN Course c ON co.CourseID = c.CourseID
JOIN Branch b ON co.BranchID = b.BranchID
JOIN Intake i ON co.IntakeID = i.IntakeID;
GO
------
--View Class Offerings
CREATE VIEW vw_ClassOfferings
AS
SELECT 
    co.CourseOfferingID,
    c.CourseName,
    ins.FullName AS InstructorName,
    i.IntakeName,
    b.BranchName,
    t.TrackName,
    co.AcademicYear
FROM CourseOffering co
JOIN Course c ON co.CourseID = c.CourseID
JOIN Instructor ins ON co.InstructorID = ins.InstructorID
JOIN Intake i ON co.IntakeID = i.IntakeID
JOIN Branch b ON co.BranchID = b.BranchID
LEFT JOIN Track t ON co.TrackID = t.TrackID;
GO

--==========================Triggers==============
---Trigger soft delete
CREATE TRIGGER trg_User_SoftDelete
ON [User]
INSTEAD OF DELETE
AS
BEGIN
    update [User] 
	set IsActive = 0
	where UserID in (select UserID from deleted)

    PRINT 'User Deleted Successfully';
END
GO

-------
create TRIGGER trg_User_PreventInvalidRoleChange
ON [User]
AFTER UPDATE
AS
BEGIN
    IF UPDATE(Role)
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM inserted i
            JOIN deleted d ON i.UserID = d.UserID
            WHERE d.Role = 'Instructor'
              AND i.Role <> 'Instructor'
              AND EXISTS (SELECT 1 FROM Instructor ins WHERE ins.UserID = i.UserID)
        )
        BEGIN
            RAISERROR('Cannot change role of linked Instructor user.',16,1)
            ROLLBACK 
        END
    END
END
GO

----------------Permissions / Security----------------------------
-- Create Logins
CREATE LOGIN AdminLogin WITH PASSWORD = '12345';
CREATE LOGIN ManagerLogin WITH PASSWORD = '12345';
CREATE LOGIN InstructorLogin WITH PASSWORD = '12345';
CREATE LOGIN StudentLogin WITH PASSWORD = '12345';

-- Create Users
CREATE USER AdminUser FOR LOGIN AdminLogin WITH DEFAULT_SCHEMA = dbo;
CREATE USER ManagerUser FOR LOGIN ManagerLogin WITH DEFAULT_SCHEMA = dbo;
CREATE USER InstructorUser FOR LOGIN InstructorLogin WITH DEFAULT_SCHEMA = dbo;
CREATE USER StudentUser FOR LOGIN StudentLogin WITH DEFAULT_SCHEMA = dbo;

-- Assign Users To Roles
ALTER ROLE AdminRole ADD MEMBER AdminUser;
ALTER ROLE ManagerRole ADD MEMBER ManagerUser;
ALTER ROLE InstructorRole ADD MEMBER InstructorUser;
ALTER ROLE StudentRole ADD MEMBER StudentUser;







--Admin Permissions
GRANT EXECUTE ON sp_CreateUser TO AdminRole;
GRANT EXECUTE ON sp_CreateInstructor TO AdminRole;
GRANT EXECUTE ON sp_CreateCourse TO AdminRole;
GRANT EXECUTE ON UpdateDepartment TO AdminRole;
GRANT EXECUTE ON sp_CreateClassOffering TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON Department TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON Branch TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON Track TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON Intake TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON Instructor TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON Student TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON Course TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON CourseOffering TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON Question TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON QuestionChoice TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON Exam TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON ExamQuestion TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON ExamStudent TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON StudentAnswer TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON StudentCourseResult TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON [User] TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON EXAM_ELIGIBILITY TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON Question_Pool TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON Question_Type TO AdminRole;










-- Training Manager Permissions
GRANT EXECUTE ON sp_CreateStudent TO ManagerRole;
GRANT EXECUTE ON sp_CreateCourse TO ManagerRole;
GRANT EXECUTE ON sp_CreateClassOffering TO ManagerRole;
GRANT EXECUTE ON UpdateDepartment TO ManagerRole;
GRANT SELECT ON vw_StudentsFullInfo TO ManagerRole;
GRANT SELECT ON vw_ClassOfferings TO ManagerRole;

GRANT SELECT, INSERT, UPDATE ON Department TO ManagerRole;
GRANT SELECT, INSERT, UPDATE ON Branch TO ManagerRole;
GRANT SELECT, INSERT, UPDATE ON Track TO ManagerRole;
GRANT SELECT, INSERT, UPDATE ON Intake TO ManagerRole;
GRANT SELECT, INSERT, UPDATE ON Instructor TO ManagerRole;
GRANT SELECT, INSERT, UPDATE ON Student TO ManagerRole;
GRANT SELECT, INSERT, UPDATE ON Course TO ManagerRole;
GRANT SELECT, INSERT, UPDATE ON CourseOffering TO ManagerRole;
GRANT SELECT ON Question TO ManagerRole;
GRANT SELECT ON QuestionChoice TO ManagerRole;
GRANT SELECT, INSERT, UPDATE ON Exam TO ManagerRole;
GRANT SELECT, INSERT, UPDATE ON ExamQuestion TO ManagerRole;
GRANT SELECT ON ExamStudent TO ManagerRole;
GRANT SELECT ON StudentAnswer TO ManagerRole;
GRANT SELECT, INSERT, UPDATE ON StudentCourseResult TO ManagerRole;


--Instructor Permissions
GRANT EXECUTE ON sp_CreateExam TO InstructorRole;
GRANT EXECUTE ON sp_AddQuestionToExam TO InstructorRole;
GRANT EXECUTE ON sp_AddExamEligibility TO InstructorRole;
GRANT EXECUTE ON GradeExamStudent TO InstructorRole;
GRANT EXECUTE ON GradeTextAnswer TO InstructorRole;
GRANT SELECT ON VW_Instructor_Exam_Results TO InstructorRole;
GRANT SELECT ON VW_Exam_Questions TO InstructorRole;
GRANT SELECT ON Course TO InstructorRole;
GRANT SELECT ON CourseOffering TO InstructorRole;
GRANT SELECT, INSERT, UPDATE ON Question TO InstructorRole;
GRANT SELECT, INSERT, UPDATE ON QuestionChoice TO InstructorRole;
GRANT SELECT, INSERT, UPDATE ON Question_Pool TO InstructorRole;
GRANT SELECT ON Question_Type TO InstructorRole;
GRANT SELECT, INSERT, UPDATE ON Exam TO InstructorRole;
GRANT SELECT, INSERT, UPDATE ON ExamQuestion TO InstructorRole;
GRANT SELECT ON ExamStudent TO InstructorRole;
GRANT SELECT, UPDATE ON StudentAnswer TO InstructorRole;
GRANT SELECT ON Student TO InstructorRole;



--Student Permissions
GRANT EXECUTE ON startExam TO StudentRole;
GRANT SELECT ON VW_Student_Results TO StudentRole;
GRANT EXECUTE ON sp_GetExamDetails TO StudentRole;
GRANT SELECT ON VW_Student_Eligible_Exams TO StudentRole;
GRANT SELECT ON Course TO StudentRole;
GRANT SELECT ON CourseOffering TO StudentRole;
GRANT SELECT ON Exam TO StudentRole;
GRANT SELECT ON ExamQuestion TO StudentRole;
GRANT SELECT ON Question TO StudentRole;
GRANT SELECT ON QuestionChoice TO StudentRole;
GRANT SELECT, INSERT ON StudentAnswer TO StudentRole;
GRANT SELECT ON ExamStudent TO StudentRole;
GRANT SELECT ON StudentCourseResult TO StudentRole;
GRANT SELECT ON EXAM_ELIGIBILITY TO StudentRole;




















---===============Backup=====================
-- Daily Automatic Backup(Recovery Model FULL)
ALTER DATABASE ADM SET RECOVERY FULL;

--Create Job (SQL Server Agent)
BACKUP DATABASE ADM
TO DISK = 'E:\My Files\ITI\Projects\SQL Project\ADM_Daily.bak'
WITH INIT, STATS = 10;



--user first to ADM database
ALTER LOGIN AdminLogin WITH DEFAULT_DATABASE = [ADM];


select * from VW_Instructor_Exam_Results