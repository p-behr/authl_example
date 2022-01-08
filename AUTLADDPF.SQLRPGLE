**free

 ctl-opt  debug option(*NODEBUGIO : *SRCSTMT);
 ctl-opt  dftactgrp(*no) actgrp(*new);

 dcl-ds todoList  qualified dim(*auto : 1000);
     lib  char(10);
     obj  char(10);
     aut  char(10);
 end-ds;
 dcl-s  i  int(10);

 dcl-pr  RunCmd  extproc('system');
     *n   pointer  value options(*string);
 end-pr;

 Exec SQL
     DECLARE addpfautl_todo_list CURSOR FOR
     SELECT lib, obj, aut
     FROM pbehr.authlist
     WHERE status = 'new';

 Exec SQL
     OPEN addpfautl_todo_list;

 Exec SQL
     FETCH addpfautl_todo_list
     FOR 1000 ROWS
     INTO :todoList;

 Exec SQL
     CLOSE addpfautl_todo_list;



 // First add the authorization list to the object
 cmd = 'GRTOBJAUT OBJ(' + %trim(lib) + '/' + %trim(obj) + ') +
                  OBJTYPE(*FILE) +
                  AUTL(' + %trim(aut) + ')';

 if RunCmd(cmd) <> 0;
     Exec SQL
      CALL SYSTOOLS.LPRINTF('>>> ERROR: Unable to add authorization list <<<');
     return;
 endif;


 // Then change *PUBLIC authority to use the autl
 cmd = 'GRTOBJAUT OBJ(' + %trim(lib) + '/' + %trim(obj) + ') +
                  OBJTYPE(*FILE) +
                  USER(*PUBLIC) AUT(*AUTL)';
 if RunCmd(cmd) <> 0;
     Exec SQL
      CALL SYSTOOLS.LPRINTF('>>> ERROR: Unable to change *PUBLIC auth <<<');
     return;
 endif;

 Exec SQL
  CALL SYSTOOLS.LPRINTF('>>> SUCCESS: Authority updated successfully <<<');
 return;


 *inlr = *on;
 return;


dcl-proc AuthListExists;
    dcl-pi *n  ind;
        in_authList  char(10) const;
    end-pi;

    dcl-s authListExists   ind;

    Exec SQL
        SELECT '1'
        INTO :authListExists
        FROM qsys2.authorization_list_user_info
        WHERE authorization_list = :in_authList
        FETCH FIRST ROW ONLY;

    if not authListExists;
        LogError('Authorization list ' + %trim(in_authList) + ' not found');
        return FAILURE;
    endif;

end-proc;



dcl-proc AddAuthList;
    dcl-pi *n  ind;
        in_library   char(10) const;
        in_file      char(10) const;
        in_authList  char(10) const;
    end-pi;

    dcl-s cmd  varchar(128);
    dcl-s authListExists   ind;

    // Make sure the authorization list exists
    Exec SQL
        SELECT '1'
        INTO :authListExists
        FROM qsys2.authorization_list_user_info
        WHERE authorization_list = :in_authList
        FETCH FIRST ROW ONLY;

    if not authListExists;
        LogError('Authorization list ' + %trim(in_authList) + ' not found');
        return FAILURE;
    endif;

    cmd = 'GRTOBJAUT OBJ(' + %trim(in_library) + '/' + %trim(in_file) + ') +
                     OBJTYPE(*FILE) +
                     AUTL(' + %trim(aut) + ')';

end-proc;


