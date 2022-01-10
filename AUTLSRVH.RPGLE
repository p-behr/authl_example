**free

/IF DEFINED(AUTLSRVH)
/EOF
/ENDIF

/DEFINE AUTLSRVH

 dcl-c SRVAUTL_SUCCESS '1';
 dcl-c SRVAUTL_ERROR   '0';
 dcl-c SRVAUTL_CMD_SUCCESS 0;


 // -------------------------------------------------------
 dcl-pr  AuthListExists  ind  extproc(*dclcase);
     in_authl   char(10) const;
 end-pr;

 // -------------------------------------------------------
 dcl-pr  LibraryExists  ind  extproc(*dclcase);
     in_lib     char(10) const;
 end-pr;

 // -------------------------------------------------------
 dcl-pr  TableExists  ind  extproc(*dclcase);
     in_lib     char(10) const;
     in_table   char(10) const;
 end-pr;

 // -------------------------------------------------------
 dcl-pr  AddAuthListToFile  ind  extproc(*dclcase);
     in_lib    char(10) const;
     in_file   char(10) const;
     in_authl  char(10) const;
 end-pr;

 // -------------------------------------------------------
 dcl-pr  SetFilePublicAuth  ind  extproc(*dclcase);
    in_lib           char(10) const;
    in_file          char(10) const;
    in_authSource    char(10) const;
    in_publicAuth    char(10) const;
 end-pr;

 // -------------------------------------------------------
 dcl-pr  RemoveAuthListFromFile  ind  extproc(*dclcase);
     in_lib    char(10) const;
     in_file   char(10) const;
     in_public char(10) const  options(*nopass : *omit);
 end-pr;

 // -------------------------------------------------------
 dcl-pr GetFileAuthList  char(10) extproc(*dclcase);
     in_lib     char(10) const;
     in_file    char(10) const;
 end-pr;

 // -------------------------------------------------------
 dcl-pr GetFilePublicAuth   char(20)  extproc(*dclcase);
     in_lib     char(10) const;
     in_file    char(10) const;
 end-pr;

 // -------------------------------------------------------
 dcl-pr GetAutlPublicAuth    char(10) extproc(*dclcase);
     in_authlist    char(10) const;
 end-pr;

 // -------------------------------------------------------
 dcl-pr CheckObject  ind  extproc(*dclcase);
     in_lib     char(10) const;
     in_obj     char(10) const;
     in_objType char(7)  const;
 end-pr;

 // -------------------------------------------------------
 dcl-pr  LogMessage  extproc(*dclcase);
     in_message  varchar(80)  const;
 end-pr;


