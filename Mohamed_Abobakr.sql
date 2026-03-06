
CREATE TABLE [Question_Pool]
(
    pool_id INT IDENTITY(1,1) NOT NULL,
    course_id INT NOT NULL,
    instructor_id INT NOT NULL,
    title NVARCHAR(200) NOT NULL,
    [description] NVARCHAR(500) NULL,
    created_at DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_Question_Pool 
        PRIMARY KEY (pool_id),

    CONSTRAINT FK_Question_Pool_Course 
        FOREIGN KEY (course_id) 
        REFERENCES [dbo].[Course](course_id),

    CONSTRAINT FK_Question_Pool_Instructor 
        FOREIGN KEY (instructor_id) 
        REFERENCES [dbo].[Instructor](instructor_id)
);
---------


CREATE TABLE [ Question_Type]
(
    question_type_id INT IDENTITY(1,1) NOT NULL,
    code NVARCHAR(50) NOT NULL,
    [description] NVARCHAR(255) NULL,

    CONSTRAINT PK_Question_Type
        PRIMARY KEY (question_type_id),

    CONSTRAINT UQ_Question_Type_Code
        UNIQUE (code)
);
------[Question]
ALTER TABLE [dbo].[Question]
ADD
    pool_id INT NULL,
    instructor_id INT NOT NULL,
    question_type_id INT NOT NULL,
    regex_rule NVARCHAR(500) NULL,
    text_eval_notes NVARCHAR(500) NULL,
    is_active BIT NOT NULL DEFAULT 1;
 ALTER TABLE [dbo].[Question]
ADD CONSTRAINT FK_Question_Pool
FOREIGN KEY (pool_id)
REFERENCES [dbo].[Question_Pool](pool_id);
ALTER TABLE [dbo].[Question]
ADD CONSTRAINT FK_Question_Instructor
FOREIGN KEY (instructor_id)
REFERENCES [dbo].[Instructor](instructor_id);
ALTER TABLE [dbo].[Question]
ADD CONSTRAINT FK_Question_QuestionType
FOREIGN KEY (question_type_id)
REFERENCES [dbo].[Question_Type](question_type_id);

--------------------QuestionChoice
ALTER TABLE [dbo].[QuestionChoice]
ADD display_order INT NOT NULL DEFAULT 1;
--------------Exam
ALTER TABLE [dbo].[Exam]
ADD
    CourseID INT NOT NULL,
    Title NVARCHAR(200) NOT NULL,
    AllowanceOptions NVARCHAR(300) NULL;
ALTER TABLE [dbo].[Exam]
ADD CONSTRAINT FK_Exam_Course
FOREIGN KEY (CourseID)
REFERENCES [dbo].[Course](CourseID);
----------------ExamQuestion
ALTER TABLE [dbo].[ExamQuestion]
ADD display_order INT NOT NULL DEFAULT 1;
ALTER TABLE [dbo].[ExamQuestion]
ADD CONSTRAINT UQ_ExamQuestion_Exam_Question
UNIQUE (ExamID, QuestionID);
----------
CREATE TABLE EXAM_ELIGIBILITY
(
    exam_eligibility_id INT IDENTITY(1,1) NOT NULL,

    exam_id INT NOT NULL,
    student_id INT NOT NULL,

    scheduled_start DATETIME NOT NULL,
    scheduled_end DATETIME NOT NULL,

    CONSTRAINT PK_EXAM_ELIGIBILITY
        PRIMARY KEY (exam_eligibility_id),

    CONSTRAINT FK_EXAM_ELIGIBILITY_Exam
        FOREIGN KEY (exam_id)
        REFERENCES [dbo].[Exam](ExamID)
        ON DELETE CASCADE,

    CONSTRAINT FK_EXAM_ELIGIBILITY_Student
        FOREIGN KEY (student_id)
        REFERENCES [dbo].[Student](student_id)
);

ALTER TABLE [dbo].[EXAM_ELIGIBILITY]
ADD CONSTRAINT UQ_EXAM_ELIGIBILITY_Exam_Student
UNIQUE (exam_id, student_id);

ALTER TABLE [dbo].[EXAM_ELIGIBILITY]
ADD CONSTRAINT CK_EXAM_ELIGIBILITY_Time
CHECK (scheduled_end > scheduled_start);
------------------------
---==================Views==================
CREATE VIEW VW_Questions_Details
AS
SELECT 
    q.QuestionID,
    q.QuestionText,
    q.is_active,
    qt.code AS QuestionType,
    qt.[description] AS QuestionTypeDescription,
    q.CourseID,
    q.pool_id,
    q.instructor_id
FROM [dbo].[Question] q
JOIN [dbo].[Question_Type] qt 
    ON q.question_type_id = qt.question_type_id;
    -------------------------
    CREATE VIEW VW_Exam_Questions
AS
SELECT
    eq.ExamID,
    e.Title AS ExamTitle,
    eq.QuestionID,
    q.QuestionText,
    eq.QuestionDegree,
    eq.display_order
FROM ExamQuestion eq
JOIN Exam e 
    ON eq.ExamID = e.ExamID
JOIN Question q 
    ON eq.QuestionID = q.QuestionID;
    --------------------------
    CREATE VIEW VW_Question_Choices
AS
SELECT
    q.QuestionID,
    q.QuestionText,
    qc.ChoiceID,
    qc.option_text,
    qc.is_correct,
    qc.display_order
FROM Question q
JOIN QuestionChoice qc
    ON q.QuestionID = qc.QuestionID;

    --------------------------
    CREATE VIEW VW_Student_Eligible_Exams
AS
SELECT
    ee.student_id,
    e.ExamID,
    e.Title,
    e.ExamType,
    e.StartDateTime,
    e.EndDateTime,
    ee.scheduled_start,
    ee.scheduled_end,
    e.DurationMinutes,
    e.TotalDegree
FROM EXAM_ELIGIBILITY ee
JOIN Exam e
    ON ee.exam_id = e.ExamID;


    ---------------------------
----
CREATE VIEW VW_Exam_Full_Details
AS
SELECT
    e.ExamID,
    e.Title,
    e.ExamType,
    e.ExamCategory,
    e.TotalDegree,
    e.DurationMinutes,
    e.AllowBacktracking,
    COUNT(eq.QuestionID) AS TotalQuestions
FROM Exam e
LEFT JOIN ExamQuestion eq
    ON e.ExamID = eq.ExamID
GROUP BY
    e.ExamID,
    e.Title,
    e.ExamType,
    e.ExamCategory,
    e.TotalDegree,
    e.DurationMinutes,
    e.AllowBacktracking;
-------------------------------
-------------
CREATE VIEW VW_QuestionPool_Stats
AS
SELECT
    qp.pool_id,
    qp.title,
    qp.course_id,
    qp.instructor_id,
    COUNT(q.QuestionID) AS TotalQuestions
FROM Question_Pool qp
LEFT JOIN Question q
    ON qp.pool_id = q.pool_id
GROUP BY
    qp.pool_id,
    qp.title,
    qp.course_id,
    qp.instructor_id;



    --===========PROCEDURES============

    ----------------
    CREATE PROCEDURE sp_AddQuestionType
    @Code NVARCHAR(50),
    @Description NVARCHAR(255)
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Question_Type WHERE code = @Code)
    BEGIN
        RAISERROR('Question Type already exists', 16, 1)
        RETURN
    END

    INSERT INTO Question_Type (code, [description])
    VALUES (@Code, @Description)
END



----------------------
CREATE PROCEDURE sp_AddQuestionChoice
    @QuestionID INT,
    @OptionText NVARCHAR(500),
    @IsCorrect BIT,
    @DisplayOrder INT
AS
BEGIN
    INSERT INTO QuestionChoice
    (
        QuestionID, option_text, is_correct, display_order
    )
    VALUES
    (
        @QuestionID, @OptionText, @IsCorrect, @DisplayOrder
    )
END
--------------------
GO
CREATE OR ALTER PROCEDURE sp_CreateExam
    @CourseOfferingID INT,
    @ExamType NVARCHAR(50),
    @ExamCategory NVARCHAR(50) = NULL,
    @Title NVARCHAR(200),
    @StartDateTime DATETIME,
    @EndDateTime DATETIME,
    @DurationMinutes INT,
    @TotalDegree DECIMAL(6,2),
    @AllowBacktracking BIT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Exam
    (
        CourseOfferingID,
        ExamType,
        ExamCategory,
        Title,
        StartDateTime,
        EndDateTime,
        DurationMinutes,
        TotalDegree,
        AllowBacktracking
    )
    VALUES
    (
        @CourseOfferingID,
        @ExamType,
        @ExamCategory,
        @Title,
        @StartDateTime,
        @EndDateTime,
        @DurationMinutes,
        @TotalDegree,
        @AllowBacktracking
    );
END
GO
---------------------
CREATE PROCEDURE sp_AddQuestionToExam
    @ExamID INT,
    @QuestionID INT,
    @QuestionDegree DECIMAL(6,2),
    @DisplayOrder INT
AS
BEGIN
    INSERT INTO ExamQuestion
    (
        ExamID, QuestionID, QuestionDegree, display_order
    )
    VALUES
    (
        @ExamID, @QuestionID, @QuestionDegree, @DisplayOrder
    )
END


-----------------------
CREATE PROCEDURE sp_AddExamEligibility
    @ExamID INT,
    @StudentID INT,
    @ScheduledStart DATETIME,
    @ScheduledEnd DATETIME
AS
BEGIN
    INSERT INTO EXAM_ELIGIBILITY
    (
        exam_id, student_id,
        scheduled_start, scheduled_end
    )
    VALUES
    (
        @ExamID, @StudentID,
        @ScheduledStart, @ScheduledEnd
    )
END
-------------------------
CREATE PROCEDURE sp_GetExamDetails
    @ExamID INT
AS
BEGIN
    SELECT 
        e.ExamID,
        e.Title,
        q.QuestionID,
        q.QuestionText,
        qc.ChoiceID,
        qc.option_text,
        qc.is_correct
    FROM Exam e
    JOIN ExamQuestion eq ON e.ExamID = eq.ExamID
    JOIN Question q ON eq.QuestionID = q.QuestionID
    LEFT JOIN QuestionChoice qc ON q.QuestionID = qc.QuestionID
    WHERE e.ExamID = @ExamID
    ORDER BY eq.display_order, qc.display_order
END