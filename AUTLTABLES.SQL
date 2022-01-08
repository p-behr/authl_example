
/**********************************************************
 * Lists all the files that are being tracked by AUTL
 **********************************************************/
 CREATE OR REPLACE TABLE pbehr.authl_tracked_tables
 FOR SYSTEM NAME autltables
 (

   tracked_table_library     FOR  tablib
     CHAR(10)                NOT NULL DEFAULT

 , tracked_table             FOR  tabnam
     CHAR(10)                NOT NULL DEFAULT

 , tracked_status            FOR  status
     CHAR(10)                NOT NULL DEFAULT 'new'
 , CONSTRAINT autltables_ck_status
   CHECK( tracked_status IN( 'new'
                           , 'pending'
                           , 'complete'
                           , 'error'
                           )
        )

 , CONSTRAINT autltables_pk
   PRIMARY KEY(tracked_table_library, tracked_table)


 , authorization_list        FOR  tabautl
     CHAR(10)                NOT NULL DEFAULT


 , public_authority          FOR  pubaut
     CHAR(10)                NOT NULL DEFAULT

 , CONSTRAINT autltables_ck_pubaut
   CHECK( public_authority IN( '*EXCLUDE'
                             , '*USE'
                             , '*CHANGE'
                             , '*ALL'
                             , ''
                             )
        )


 , public_auth_source        FOR  pubsrc
     CHAR(10)                NOT NULL DEFAULT

 , CONSTRAINT autltables_ck_pubsrc
   CHECK( public_auth_source IN( '*FILE'
                               , '*AUTL'
                               , ''
                               )
        )


 , created_by_user           FOR crtusr
     VARCHAR(18)             NOT NULL DEFAULT user

 , created_timestamp         FOR crtts
     TIMESTAMP               NOT NULL DEFAULT current timestamp

 , changed_by_job            FOR chgjob
     VARCHAR(28)             NOT NULL
                             GENERATED ALWAYS AS (QSYS2.JOB_NAME)

 , changed_timestamp         FOR chgts
     TIMESTAMP               NOT NULL
                             FOR EACH ROW ON UPDATE
                             AS ROW CHANGE TIMESTAMP
 )
RCDFMT autltabrec
ON REPLACE DELETE ROWS
;



LABEL ON TABLE pbehr.authl_tracked_tables
IS 'Lists the files being tracked by AUTL'
;


LABEL ON COLUMN pbehr.authl_tracked_tables
(
  tracked_table_library IS 'Library'
, tracked_table         IS 'Table'
, tracked_status        IS 'Tracking            Status'
, authorization_list    IS 'Authorization       List'
, public_authority      IS 'Public              Authority'
, created_by_user       IS 'Created             By User'
, created_timestamp     IS 'Created             Timestamp'
, changed_by_job        IS 'Updated             By Job'
, changed_timestamp     IS 'Updated             Timestamp'
)
;



LABEL ON COLUMN pbehr.authl_tracked_tables
(
  tracked_table_library TEXT IS 'Library'
, tracked_table         TEXT IS 'Table Name'
, tracked_status        TEXT IS 'Tracking Status'
, authorization_list    TEXT IS 'Authorization List'
, public_authority      TEXT IS 'Public Authority'
, created_by_user       TEXT IS 'Created By User'
, created_timestamp     TEXT IS 'Created On Timestamp'
, changed_by_job        TEXT IS 'Updated By Job'
, changed_timestamp     TEXT IS 'Updated On Timestamp'
)
;





