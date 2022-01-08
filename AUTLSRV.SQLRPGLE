**free

 ctl-opt  nomain;
 /IF DEFINED(*CRTBNDRPG)
 ctl-opt  dftactgrp(*no) actgrp(*caller);
 ctl-opt  pgminfo(*pcml: *dclcase : *module);
 /ENDIF
 ctl-opt  bnddir('QC2LE');

 /copy SRVAUTL_H

 dcl-pr RunCmd  int(10)  extproc('system');
     *n    pointer   value options(*string);
 end-pr;


 // -------------------------------------------------------
 // AuthListExists
 // Checks to see if an authorization list exists
 // -------------------------------------------------------
 dcl-proc  AuthListExists  export;
     dcl-pi *n  ind;
         in_authl   char(10) const;
     end-pi;

     return CheckObject('QSYS' : in_authl : '*AUTL');
 end-proc  AuthListExists;


 // -------------------------------------------------------
 // LibraryExists
 // Checks to see if a library exists
 // -------------------------------------------------------
 dcl-proc  LibraryExists  export;
     dcl-pi *n  ind;
         in_lib   char(10) const;
     end-pi;

     return CheckObject('QSYS' : in_lib : '*LIB');
 end-proc  LibraryExists;


 // -------------------------------------------------------
 // TableExists
 // Checks to see if a table exists
 // -------------------------------------------------------
 dcl-proc  TableExists  export;
     dcl-pi *n  ind;
         in_lib   char(10) const;
         in_table char(10) const;
     end-pi;

     return CheckObject(in_lib : in_table : '*FILE');
 end-proc  TableExists;



 // -------------------------------------------------------
 // AddAuthListToFile
 // Adds an authorization list to a file
 // -------------------------------------------------------
 dcl-proc  AddAuthListToFile  export;
     dcl-pi *n  ind;
         in_lib     char(10) const;
         in_file    char(10) const;
         in_authl   char(10) const;
     end-pi;

     dcl-s  cmd   varchar(128);
     dcl-s  qualFile varchar(21);

     qualFile = %trim(in_lib) + '/' + %trim(in_file);

     // Make sure the authorization list exists
     if not AuthListExists(in_authl);
         LogMessage('ERROR: *AUTL "' + %trim(in_authl) + '" not found');
         return SRVAUTL_ERROR;
     endif;


     // First we want to add the authorization list to the file
     cmd = 'GRTOBJAUT OBJ(' + qualFile + ') +
                      OBJTYPE(*FILE) +
                      AUTL(' + %trim(in_authl) + ')';

     if RunCmd(cmd) <> SRVAUTL_CMD_SUCCESS;
         LogMessage('ERROR: *AUTL "' + %trim(in_authl) + '" not added to ' + qualFile);
         return SRVAUTL_ERROR;
     endif;

     // Then we want *PUBLIC authority to come from *AUTL
     cmd = 'GRTOBJAUT OBJ(' + qualFile + ') +
                      OBJTYPE(*FILE) +
                      USER(*PUBLIC) +
                      AUT(*AUTL)';

     if RunCmd(cmd) <> SRVAUTL_CMD_SUCCESS;
         LogMessage('ERROR: *PUBLIC authority for ' + qualFile + ' not set');
         return SRVAUTL_ERROR;
     endif;

     return SRVAUTL_SUCCESS;
 end-proc  AddAuthListToFile;


 // -------------------------------------------------------
 // RemoveAuthListFromFile
 // -------------------------------------------------------
 dcl-proc  RemoveAuthListFromFile  export;
     dcl-pi *n  ind;
         in_lib     char(10) const;
         in_file    char(10) const;
         in_public  char(10) const;
     end-pi;

     dcl-s  cmd   varchar(128);
     dcl-s  qualFile varchar(21);

     qualFile = %trim(in_lib) + '/' + %trim(in_file);


     // Check that we have a valid *PUBLIC authority
     if in_public <> '*CHANGE'
     and in_public <> '*ALL'
     and in_public <> '*USE'
     and in_public <> '*EXCLUDE';
         LogMessage('ERROR: "' + %trim(in_public) + '" is not valid authority');
         return SRVAUTL_ERROR;
     endif;


     // Remove the authorization list
     cmd = 'GRTOBJAUT OBJ(' + qualFile + ') +
                      OBJTYPE(*FILE) +
                      AUTL(*NONE)';

     if RunCmd(cmd) <> SRVAUTL_CMD_SUCCESS;
         LogMessage('ERROR: *AUTL not removed from ' + qualFile);
         return SRVAUTL_ERROR;
     endif;


     // Set the *PUBLIC authority
     cmd = 'GRTOBJAUT OBJ(' + qualFile + ') +
                      OBJTYPE(*FILE) +
                      USER(*PUBLIC) +
                      AUT(' + %trim(in_public) + ')';

     if RunCmd(cmd) <> SRVAUTL_CMD_SUCCESS;
         LogMessage('ERROR: *PUBLIC authority for ' + qualFile + ' not set');
         return SRVAUTL_ERROR;
     endif;

     return SRVAUTL_SUCCESS;
 end-proc  RemoveAuthListFromFile;


 // -------------------------------------------------------
 // GetFileAuthList
 // Returns the authorization list associated with a file
 // -------------------------------------------------------
 dcl-proc  GetFileAuthList  export;
     dcl-pi *n  char(10);
         in_lib     char(10) const;
         in_file    char(10) const;
     end-pi;

     dcl-s  authList  char(10);
     dcl-s  qualFile  varchar(21);

     Exec SQL
      SELECT authorization_list
      INTO :authList
      FROM qsys2.AUTHORIZATION_LIST_INFO
      WHERE system_object_schema = :in_lib
        AND system_object_name = :in_file;

     if authList = *blanks;
         qualFile = %trim(in_lib) + '/' + %trim(in_file);
         LogMessage('ERROR: No auth list found for ' + %trim(qualFile));
     endif;

     return authList;
 end-proc  GetFileAuthList;



 // -------------------------------------------------------
 // GetFilePublicAuth
 // Returns the *PUBLIC authority to the file and where it comes from
 // Returns 1-10  = *PUBLIC authority (i.e. "*ALL", "*CHANGE", etc.)
 // Returns 11-20 = Source *AUTL or *FILE
 // -------------------------------------------------------
 dcl-proc  GetFilePublicAuth  export;
     dcl-pi *n      char(20);
         in_lib     char(10) const;
         in_file    char(10) const;
     end-pi;

     dcl-ds publicAuth qualified;
         authority   char(10);
         source      char(10);
     end-ds;

     dcl-s  authority  varchar(12);
     dcl-s  authList   char(10);

     Exec SQL
      SELECT object_authority, COALESCE(authorization_list , '')
      INTO :authority, :authList
      FROM TABLE(
          QSYS2.OBJECT_PRIVILEGES(
               system_object_schema => :in_lib
             , system_object_name => :in_file
             , object_type => 'FILE'
          )
      )
      WHERE authorization_user = '*PUBLIC';

     if authority = '*AUTL';
         publicAuth.source = '*AUTL';
         publicAuth.authority = GetAutlPublicAuth(authList);
     else;
         publicAuth.source = '*FILE';
         publicAuth.authority = authority;
     endif;

     return publicAuth;
 end-proc;


 // -------------------------------------------------------
 // GetAutlPublicAuth
 // Returns the *PUBLIC authority for the authorization list
 // -------------------------------------------------------
 dcl-proc  GetAutlPublicAuth  export;
     dcl-pi *n          char(10);
         in_authlist    char(10) const;
     end-pi;

     dcl-s  authority  varchar(12);

     Exec SQL
      SELECT object_authority
      INTO :authority
      FROM qsys2.authorization_list_user_info
      WHERE authorization_list = :in_authList
        AND authorization_name = '*PUBLIC';

     return authority;
 end-proc;


 // -------------------------------------------------------
 // CheckObject
 // Checks to see if an object exists
 // -------------------------------------------------------
 dcl-proc  CheckObject  export;
     dcl-pi *n  ind;
         in_lib     char(10) const;
         in_obj     char(10) const;
         in_objType char(7) const;
     end-pi;

     dcl-s  cmd   varchar(128);
     dcl-s  objExists  ind;

     cmd = 'CHKOBJ OBJ(' + %trim(in_lib) + '/' + %trim(in_obj) + ') +
                   OBJTYPE(' + %trim(in_objType) + ')';
     if RunCmd(cmd) = 0;
         objExists = *on;
     endif;

     return objExists;
 end-proc  CheckObject;

 // -------------------------------------------------------
 // LogMessage
 // Logs a message to the job log
 // -------------------------------------------------------
 dcl-proc  LogMessage  export;
     dcl-pi *n;
         in_message   varchar(80) const;
     end-pi;

     dcl-s msg varchar(80);

     msg = '====================================';
     Exec SQL
       CALL SYSTOOLS.LPRINTF(:msg);

     msg = '==      AUTLSRV LOG MESSAGE       ==';
     Exec SQL
       CALL SYSTOOLS.LPRINTF(:msg);

     msg = '====================================';
     Exec SQL
       CALL SYSTOOLS.LPRINTF(:msg);

     msg = in_message;
     Exec SQL
       CALL SYSTOOLS.LPRINTF(:msg);

     msg = '====================================';
     Exec SQL
       CALL SYSTOOLS.LPRINTF(:msg);


     return;
 end-proc;


