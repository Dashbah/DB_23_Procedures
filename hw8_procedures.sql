CREATE PROCEDURE AddNewJob(job_id varchar(10), job_title varchar(35), min_salary int)
    LANGUAGE plpgsql
AS
$$
BEGIN
    INSERT INTO jobs(job_id, job_title, min_salary, max_salary)
    VALUES (job_id, job_title, min_salary, min_salary * 2);
END;
$$;

CALL AddNewJob('SY_ANAL2', 'System Analyst', 5000);

CREATE OR REPLACE PROCEDURE ADD_JOB_HIST(emp_id INT, new_job_id VARCHAR(10))
LANGUAGE plpgsql
AS
$$
DECLARE
    hire_date DATE;
BEGIN
    -- Get the hire date of the employee
    SELECT hire_date INTO hire_date FROM employees WHERE employee_id = emp_id;

    -- Insert into JOB_HISTORY
    INSERT INTO job_history(employee_id, start_date, end_date, job_id, department_id)
    VALUES (emp_id, hire_date, CURRENT_DATE, new_job_id, (SELECT department_id FROM employees WHERE employee_id = emp_id));

    -- Update employee's hire date and job
    UPDATE employees SET hire_date = CURRENT_DATE, job_id = new_job_id, salary = (SELECT min_salary + 500 FROM jobs WHERE job_id = new_job_id) WHERE employee_id = emp_id;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Employee with ID % not found', emp_id;
END;
$$;


CREATE OR REPLACE PROCEDURE UPD_JOBSAL(job_id1 VARCHAR(10), new_min_salary INT, new_max_salary INT)
LANGUAGE plpgsql
AS
$$
BEGIN
    -- Check if job_id exists
    IF NOT EXISTS (SELECT 1 FROM jobs WHERE job_id = job_id1) THEN
        RAISE EXCEPTION 'Job ID % not found', job_id1;
    END IF;

    -- Check if max_salary is greater than or equal to min_salary
    IF new_max_salary < new_min_salary THEN
        RAISE EXCEPTION 'Max salary cannot be less than min salary';
    END IF;

    -- Attempt to update the job
    UPDATE jobs SET min_salary = new_min_salary, max_salary = new_max_salary WHERE job_id = job_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Row is locked/busy';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION GET_YEARS_SERVICE(emp_id INT)
RETURNS INTEGER
LANGUAGE plpgsql
AS
$$
DECLARE
    years_of_service INTEGER;
BEGIN
    -- Get years of service
    SELECT EXTRACT(YEAR FROM AGE(CURRENT_DATE, hire_date)) INTO years_of_service
    FROM employees WHERE employee_id = emp_id;

    RETURN years_of_service;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Employee with ID % not found', emp_id;
END;
$$;


CREATE OR REPLACE FUNCTION GET_JOB_COUNT(emp_id INT)
RETURNS INTEGER
LANGUAGE plpgsql
AS
$$
DECLARE
    job_count INTEGER;
BEGIN
    -- Get the count of different jobs for the employee
    SELECT COUNT(DISTINCT job_id)
    INTO job_count
    FROM job_history
    WHERE employee_id = emp_id;

    RETURN job_count;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Employee with ID % not found', emp_id;
END;
$$;


CREATE OR REPLACE FUNCTION CHECK_SAL_RANGE()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE
    new_min_salary INT;
    new_max_salary INT;
BEGIN
    -- Extract new values
    new_min_salary := NEW.min_salary;
    new_max_salary := NEW.max_salary;

    -- Check if salary range change affects existing employees
    IF EXISTS (
        SELECT 1
        FROM employees
        WHERE job_id = NEW.job_id
        AND (salary < new_min_salary OR salary > new_max_salary)
    ) THEN
        RAISE EXCEPTION 'Salary range change affects existing employees';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER CHECK_SAL_RANGE
BEFORE UPDATE OF min_salary, max_salary ON jobs
FOR EACH ROW
EXECUTE FUNCTION CHECK_SAL_RANGE();


