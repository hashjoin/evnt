CREATE OR REPLACE TRIGGER sid_credentials_biu
 BEFORE INSERT or UPDATE
 ON SID_CREDENTIALS
 FOR EACH ROW
-- PL/SQL Block
DECLARE
    l_sid_name sids.s_name%type;
    l_db_link_name SID_CREDENTIALS.sc_db_link_name%type;
BEGIN
    SELECT s_name INTO l_sid_name
    FROM sids
    WHERE s_id = :new.s_id;

    create_db_link(l_sid_name,:new.sc_username,:new.sc_password,:new.sc_tns_alias,l_db_link_name);

    --:new.sc_password := '****';
    :new.sc_db_link_name := l_db_link_name;
END;
/
