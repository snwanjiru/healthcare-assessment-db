-- 1) Create a dedicated database
CREATE DATABASE IF NOT EXISTS healthcare_assessment_dev
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- 2) Select / Use that database
USE healthcare_assessment_dev;

-- Lookup tables
CREATE TABLE IF NOT EXISTS symptom (
    symptom_id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(32) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS measure_unit (
    unit_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64) NOT NULL UNIQUE,
    symbol VARCHAR(32),
    description VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS diagnosis_code (
    code_id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(32) NOT NULL UNIQUE,
    display TEXT NOT NULL,
    description TEXT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS data_source (
    data_source_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64) NOT NULL UNIQUE,
    description VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS role (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255)
) ENGINE=InnoDB;

-- Core user/patient/clinician tables
CREATE TABLE IF NOT EXISTS app_user (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(150) UNIQUE,
    role_id INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    FOREIGN KEY (role_id) REFERENCES role(role_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS patient (
    patient_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL UNIQUE,
    external_patient_ref VARCHAR(100),
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender ENUM('Male','Female','Other','Unknown') DEFAULT 'Unknown',
    primary_contact VARCHAR(100),
    address VARCHAR(255),
    nationality VARCHAR(64),
    language VARCHAR(64),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE (first_name, last_name, date_of_birth),
    FOREIGN KEY (user_id) REFERENCES app_user(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS clinician (
    clinician_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL UNIQUE,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    specialty VARCHAR(120),
    license_number VARCHAR(80) UNIQUE,
    organization VARCHAR(150),
    contact_info VARCHAR(150),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES app_user(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS consent (
    consent_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    consent_type ENUM('Research','Clinical','Analytics','Other') NOT NULL,
    consent_text TEXT NOT NULL,
    consent_granted TINYINT(1) NOT NULL DEFAULT 1,
    granted_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_on TIMESTAMP NULL,
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id) 
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Observations and related tables
CREATE TABLE IF NOT EXISTS observation (
    observation_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    data_source_id INT NOT NULL,
    observed_at DATETIME NOT NULL,
    recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    location VARCHAR(128),
    notes TEXT,
    timezone VARCHAR(64) DEFAULT 'UTC',
    device_id VARCHAR(100),
    app_version VARCHAR(50),
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (data_source_id) REFERENCES data_source(data_source_id) ON DELETE RESTRICT,
    INDEX (patient_id, observed_at),
    INDEX (recorded_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS observation_symptom (
    observation_symptom_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    observation_id BIGINT NOT NULL,
    symptom_id INT NOT NULL,
    severity TINYINT NOT NULL CHECK(severity BETWEEN 0 AND 10),
    onset_date DATE,
    duration_days INT DEFAULT 0 CHECK(duration_days >= 0),
    is_current TINYINT(1) DEFAULT 1,
    free_text_note TEXT,
    FOREIGN KEY (observation_id) REFERENCES observation(observation_id) ON DELETE CASCADE,
    FOREIGN KEY (symptom_id) REFERENCES symptom(symptom_id) ON DELETE RESTRICT,
    UNIQUE (observation_id, symptom_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS measurement (
    measurement_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    observation_id BIGINT NOT NULL,
    metric VARCHAR(100) NOT NULL,
    value DECIMAL(10,4) NOT NULL,
    unit_id INT NULL,
    reference_low DECIMAL(10,4) NULL,
    reference_high DECIMAL(10,4) NULL,
    measured_at DATETIME NOT NULL,
    FOREIGN KEY (observation_id) REFERENCES observation(observation_id) ON DELETE CASCADE,
    FOREIGN KEY (unit_id) REFERENCES measure_unit(unit_id) ON DELETE SET NULL,
    INDEX (metric, measured_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS attachment (
    attachment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    observation_id BIGINT NOT NULL,
    filename VARCHAR(255) NOT NULL,
    content_type VARCHAR(100),
    storage_path VARCHAR(512) NOT NULL,
    uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (observation_id) REFERENCES observation(observation_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Encounters, assessments, recommendations parts
CREATE TABLE IF NOT EXISTS encounter (
    encounter_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT NOT NULL,
    clinician_id INT NULL,
    encounter_datetime DATETIME NOT NULL,
    encounter_type ENUM('InPerson','Telemedicine','Phone','Asynchronous') DEFAULT 'InPerson',
    reason_for_visit VARCHAR(255),
    summary TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (clinician_id) REFERENCES clinician(clinician_id) ON DELETE SET NULL,
    INDEX (patient_id, encounter_datetime)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS assessment (
    assessment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    encounter_id BIGINT NULL,
    clinician_id INT NOT NULL,
    patient_id INT NOT NULL,
    assessment_datetime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assessment_text TEXT,
    final_diagnosis_code INT NULL,
    final_diagnosis_text VARCHAR(255),
    confidence DECIMAL(3,2) DEFAULT 0.00 CHECK(confidence >= 0 AND confidence <= 1),
    follow_up_days INT DEFAULT NULL,
    FOREIGN KEY (encounter_id) REFERENCES encounter(encounter_id) ON DELETE SET NULL,
    FOREIGN KEY (clinician_id) REFERENCES clinician(clinician_id) ON DELETE RESTRICT,
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (final_diagnosis_code) REFERENCES diagnosis_code(code_id) ON DELETE SET NULL,
    INDEX (patient_id, assessment_datetime)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS assessment_observation (
    assessment_id BIGINT NOT NULL,
    observation_id BIGINT NOT NULL,
    contribution_type ENUM('Direct','Supporting','Historical') DEFAULT 'Supporting',
    PRIMARY KEY (assessment_id, observation_id),
    FOREIGN KEY (assessment_id) REFERENCES assessment(assessment_id) ON DELETE CASCADE,
    FOREIGN KEY (observation_id) REFERENCES observation(observation_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS differential_diagnosis (
    diff_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    assessment_id BIGINT NOT NULL,
    code_id INT NULL,
    diagnosis_text VARCHAR(255) NOT NULL,
    probability DECIMAL(5,4) CHECK(probability >= 0 AND probability <= 1),
    diagnosis_rank INT NOT NULL DEFAULT 1,
    FOREIGN KEY (assessment_id) REFERENCES assessment(assessment_id) ON DELETE CASCADE,
    FOREIGN KEY (code_id) REFERENCES diagnosis_code(code_id) ON DELETE SET NULL,
    UNIQUE (assessment_id, diagnosis_rank)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS recommendation (
    recommendation_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    assessment_id BIGINT NOT NULL,
    recommended_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    rec_type ENUM('Treatment','Lifestyle','Referral','Test','FollowUp','Education','Other') NOT NULL,
    rec_text TEXT NOT NULL,
    due_date DATE,
    fulfilled TINYINT(1) DEFAULT 0,
    fulfilled_on DATE NULL,
    FOREIGN KEY (assessment_id) REFERENCES assessment(assessment_id) ON DELETE CASCADE,
    INDEX (assessment_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS lab_order (
    order_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    recommendation_id BIGINT NULL,
    patient_id INT NOT NULL,
    ordered_by INT NULL,
    ordered_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Ordered','Completed','Cancelled') DEFAULT 'Ordered',
    notes TEXT,
    FOREIGN KEY (recommendation_id) REFERENCES recommendation(recommendation_id) ON DELETE SET NULL,
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (ordered_by) REFERENCES clinician(clinician_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS lab_result (
    lab_result_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT NOT NULL,
    metric VARCHAR(128) NOT NULL,
    value_text VARCHAR(255),
    value_numeric DECIMAL(14,6) NULL,
    unit_id INT NULL,
    reference_low DECIMAL(14,6) NULL,
    reference_high DECIMAL(14,6) NULL,
    measured_at DATETIME NULL,
    result_reported_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES lab_order(order_id) ON DELETE CASCADE,
    FOREIGN KEY (unit_id) REFERENCES measure_unit(unit_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- PROM questionnaire tables
CREATE TABLE IF NOT EXISTS questionnaire (
    questionnaire_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    version VARCHAR(32),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (title, version)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS question (
    question_id INT AUTO_INCREMENT PRIMARY KEY,
    questionnaire_id INT NOT NULL,
    ordinal INT NOT NULL,
    question_text TEXT NOT NULL,
    response_type ENUM('Boolean','Numeric','Text','Choice','Scale') NOT NULL,
    choice_options JSON NULL,
    required TINYINT(1) DEFAULT 0,
    FOREIGN KEY (questionnaire_id) REFERENCES questionnaire(questionnaire_id) ON DELETE CASCADE,
    UNIQUE (questionnaire_id, ordinal)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS questionnaire_response (
    response_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    questionnaire_id INT NOT NULL,
    patient_id INT NOT NULL,
    filled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responder_user_id INT NULL,
    metadata JSON NULL,
    FOREIGN KEY (questionnaire_id) REFERENCES questionnaire(questionnaire_id) ON DELETE CASCADE,
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (responder_user_id) REFERENCES app_user(user_id) ON DELETE SET NULL,
    INDEX (patient_id, filled_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS question_response (
    question_response_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    response_id BIGINT NOT NULL,
    question_id INT NOT NULL,
    response_text TEXT,
    response_numeric DECIMAL(14,6) NULL,
    response_choice VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (response_id) REFERENCES questionnaire_response(response_id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES question(question_id) ON DELETE CASCADE,
    UNIQUE (response_id, question_id)
) ENGINE=InnoDB;

-- Audit / logging
CREATE TABLE IF NOT EXISTS audit_log (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    event_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    action VARCHAR(100) NOT NULL,
    object_type VARCHAR(100),
    object_id VARCHAR(128),
    details JSON,
    ip_address VARCHAR(64),
    FOREIGN KEY (user_id) REFERENCES app_user(user_id) ON DELETE SET NULL,
    INDEX (user_id, event_time)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS access_audit (
    access_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    accessor_user_id INT NOT NULL,
    accessed_patient_id INT NOT NULL,
    accessed_table VARCHAR(128),
    accessed_object_id VARCHAR(128),
    access_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    purpose VARCHAR(255),
    FOREIGN KEY (accessor_user_id) REFERENCES app_user(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (accessed_patient_id) REFERENCES patient(patient_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Add indexes
CREATE INDEX idx_obs_patient_obs_at ON observation (patient_id, observed_at);
CREATE INDEX idx_assessment_patient_time ON assessment (patient_id, assessment_datetime);

show tables;

