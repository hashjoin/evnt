CREATE OR REPLACE TRIGGER report_shr_prms_biu
 BEFORE INSERT or UPDATE
 ON REPORT_SHR_PRMS
 FOR EACH ROW
-- PL/SQL Block
BEGIN
    :new.rsp_code := UPPER(:new.rsp_code);
END;
/
