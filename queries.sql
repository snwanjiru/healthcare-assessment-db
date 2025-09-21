USE healthcare_assessment_dev;

-- 1. List all observations for patient “Alice Njuguna”
SELECT o.observation_id, o.observed_at, o.notes
FROM observation o
JOIN patient p ON o.patient_id = p.patient_id
WHERE p.first_name = 'Alice' AND p.last_name = 'Njuguna';

-- 2. For each observation, list its symptoms and severity
SELECT o.observation_id, s.name AS symptom, os.severity
FROM observation_symptom os
JOIN observation o ON os.observation_id = o.observation_id
JOIN symptom s ON os.symptom_id = s.symptom_id
WHERE o.patient_id = (SELECT patient_id FROM patient WHERE first_name = 'Alice' AND last_name = 'Njuguna');

-- 3. Show assessment(s) for Alice with their diagnosis and confidence
SELECT a.assessment_id, a.final_diagnosis_text, a.confidence
FROM assessment a
JOIN patient p ON a.patient_id = p.patient_id
WHERE p.first_name = 'Alice' AND p.last_name = 'Njuguna';

-- 4. Show differential diagnoses for that assessment
SELECT dd.diagnosis_text, dd.probability, dd.diagnosis_rank
FROM differential_diagnosis dd
WHERE dd.assessment_id = @assess1
ORDER BY dd.diagnosis_rank;

-- 5. Show recommendation given to Alice
SELECT rec.rec_text, rec.rec_type, rec.due_date
FROM recommendation rec
WHERE rec.assessment_id = @assess1;

-- 6. Check that observation → assessment link is correct
SELECT a.assessment_id, o.observation_id, o.observed_at, a.final_diagnosis_text
FROM assessment_observation ao
JOIN assessment a ON ao.assessment_id = a.assessment_id
JOIN observation o ON ao.observation_id = o.observation_id
WHERE a.patient_id = (SELECT patient_id FROM patient WHERE first_name = 'Alice' AND last_name = 'Njuguna');

-- 7. Verify that sample symptom severity shows up
SELECT o.observation_id, s.name AS symptom, os.severity, os.duration_days
FROM observation_symptom os
JOIN symptom s ON os.symptom_id = s.symptom_id
WHERE os.observation_id = (SELECT observation_id FROM observation WHERE patient_id = (SELECT patient_id FROM patient WHERE first_name = 'Alice' AND last_name = 'Njuguna') LIMIT 1);

-- 8. Check that the differential diagnoses sum (roughly) to 1 (or the probability column values make sense)
SELECT SUM(probability) AS sum_prob, COUNT(*) AS count_dd
FROM differential_diagnosis
WHERE assessment_id = @assess1;
