**free

ctl-opt  debug option(*NODEBUGIO : *SRCSTMT);
ctl-opt  dftactgrp(*no) actgrp(*new);
ctl-opt  bnddir('AUTLBNDDIR');

dcl-ds todoList  qualified;
    lib    char(10);
    file   char(10);
    autl   char(10);
    pub    char(10);
    src    char(10);
end-ds;
dcl-s  endFile  ind;
dcl-s  newStatus  char(10);

/include *LIBL/AUTHLIST,AUTLSRVH

Exec SQL
SET OPTION COMMIT = *NONE;

Exec SQL
    DECLARE autlupdate_todo_list CURSOR FOR
    SELECT tracked_table_library
         , tracked_table
         , authorization_list
         , public_authority
         , public_auth_source
    FROM pbehr.authl_tracked_tables
    WHERE status = 'pending'
    FOR UPDATE OF tracked_status;

Exec SQL
    OPEN autlupdate_todo_list;

dou endFile;

    Exec SQL
        FETCH autlupdate_todo_list
        INTO :todoList;

    if sqlcode < 0
    or sqlcode = 100;
        endFile = *on;
        iter;
    endif;

    newStatus = 'error';

    // Remove AUTL
    if todoList.autl = *blanks;
        if  RemoveAuthListFromFile(
                todoList.lib :
                todoList.file :
                todoList.pub
            ) = SRVAUTL_SUCCESS;
            newStatus = 'complete';
        endif;

    // Add/Change AUTL
    else;
        if  AddAuthListToFile(
                todoList.lib :
                todoList.file :
                todoList.autl
            ) = SRVAUTL_SUCCESS
        and SetFilePublicAuth(
                todoList.lib  :
                todoList.file :
                todoList.src  :
                todoList.pub
            ) = SRVAUTL_SUCCESS;
            newStatus = 'complete';
        endif;
    endif;

    Exec SQL
        UPDATE pbehr.authl_tracked_tables
        SET tracked_status = :newStatus
        WHERE CURRENT OF autlupdate_todo_list;

enddo;


Exec SQL
    CLOSE autlupdate_todo_list;

*inlr = *on;
return;
