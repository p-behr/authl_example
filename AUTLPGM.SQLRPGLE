**free

ctl-opt  option(*srcstmt: *nodebugio);
/IF DEFINED(*CRTBNDRPG)
ctl-opt  dftactgrp(*no) actgrp('AUTLPGM');
ctl-opt  bnddir('AUTLBNDDIR');
/ENDIF


dcl-f  AUTLDSPF     workstn
                    extdesc('PBEHR/AUTLDSPF') extfile(*extdesc)
                    infds(dspf_info)  indds(dspf_inds)
                    sfile( sfl1 : rrn1 );

dcl-f  AUTLTABLES   extdesc('PBEHR/AUTLTABLES') extfile(*extdesc)
                    keyed
                    alias
                    rename( autltabrec : db_row );


dcl-ds  dspf_info;
  keyPressed    char(1)  pos(369);
end-ds;
dcl-ds  dspf_inds;
    S1_Dsp             ind      pos(1);
    S1_DspCtl          ind      pos(2);
    S1_NxtChg          ind      pos(3);
    S1_FoldDrop        ind      pos(4);
    C1_Change          ind      pos(5);
    S1_Errors          char(4)  pos(10);
      TABAUTL_Red      ind      pos(10);
      PUBAUT_Red       ind      pos(11);
      PUBSRC_Red       ind      pos(12);
      USERINPUT_Error  ind      pos(13);
    W2_ProtectFile     ind      pos(20);
    W2_Errors          char(5)  pos(21);
      W2_Tablib_ERR    ind      pos(21);
      W2_Tabnam_ERR    ind      pos(22);
      W2_Tabautl_ERR   ind      pos(23);
      W2_PubAut_ERR    ind      pos(24);
      W2_PubSrc_ERR    ind      pos(25);
end-ds;
dcl-s rrn1      int(5);

/include *LIBL/AUTHLIST,AUTLPSDS
/include *LIBL/AUTHLIST,AUTLFKEY
/include *LIBL/AUTHLIST,AUTLSRVH


dcl-s  reload   ind  inz(*on);
dcl-c  MORE_INFO  '0';
dcl-c  LESS_INFO  '1';
dcl-ds filter;
    C1LIB;
    C1FILE;
    C1AUTL;
    C1STATUS;
end-ds;


Exec SQL
 SET OPTION COMMIT = *NONE;

dou keyPressed = F3;

    if reload;
        reload = *off;
        AUTLPGM_LoadS1(filter);
    endif;

    write KEY1;
    write MSGSFLC;
    exfmt CTL1;

    ClearProgramMessages();
    S1_FoldDrop = S1MODE;

    select;
    when keyPressed = F3;
        leave;

    when keyPressed = F5;
        clear filter;
        reload = *on;

    when keyPressed = F6;
        if AUTLPGM_AddNew(C1LIB : C1FILE);
            reload = *on;
        endif;

    when C1_Change;
        reload = *on;

    when keyPressed = Enter;
        if AUTLPGM_ProcessS1();
            reload = *on;
        endif;

    endsl;

enddo;


    *inlr = *on;
    return;



//=========================================================
dcl-proc  AUTLPGM_ProcessS1;
    dcl-pi  *n  ind;
    end-pi;

    dcl-s  newStatus  char(10);

    dou %eof(AUTLDSPF);

        readc SFL1;
        if %eof(AUTLDSPF);
            iter;
        endif;

        select;

            when USERINPUT <> *blanks
             and USERINPUT <> '2'
             and USERINPUT <> '4'
             and USERINPUT <> 'S';
                SendProgramMessage('Invalid option "' + USERINPUT + '"');
                USERINPUT_Error = *on;
                S1_NxtChg = *on;
                update SFL1;

            when USERINPUT = *blanks;
                USERINPUT_Error = *off;
                update SFL1;

            when USERINPUT = '2';
                if AUTLPGM_Edit(
                    S1TABLIB : S1TABNAM : S1TABAUTL : S1PUBAUT : S1PUBSRC : S1STATUS
                );
                    clear S1_Errors;
                    if s1tabautl <> s1actautl;
                        TABAUTL_Red = *on;
                    endif;
                    if s1pubaut <> s1actpub;
                        PUBAUT_Red = *on;
                    endif;
                    if s1pubsrc <> s1actsrc;
                        PUBSRC_Red = *on;
                    endif;
                    clear USERINPUT;
                else;
                    USERINPUT_Error = *on;
                    S1_NxtChg = *on;
                endif;
                update SFL1;

            when USERINPUT = '4';
                Exec SQL
                    DELETE pbehr.authl_tracked_tables
                    WHERE tracked_table_library = :S1TABLIB
                      AND tracked_table = :S1TABNAM;

                if sqlcode = 0;
                    USERINPUT_Error = *off;
                    clear SFL1;
                    S1TABLIB = '*DELETED';
                else;
                    USERINPUT_Error = *on;
                    SendProgramMessage('Row not deleted; SQLCODE: '
                                       + %char(sqlcode));
                    S1_NxtChg = *on;
                endif;
                update SFL1;

            when USERINPUT = 'S';
                if S1STATUS = 'pending';
                    newStatus = 'complete';
                else;
                    newStatus = 'pending';
                endif;
                Exec SQL
                    UPDATE pbehr.authl_tracked_tables
                    SET tracked_status = :newStatus
                    WHERE tracked_table_library = :S1TABLIB
                      AND tracked_table = :S1TABNAM;

                if sqlcode = 0;
                    clear USERINPUT;
                    USERINPUT_Error = *off;
                    S1STATUS = newStatus;
                else;
                    USERINPUT_Error = *on;
                    SendProgramMessage('Status not updated; SQLCODE: '
                                       + %char(sqlcode));
                    S1_NxtChg = *on;
                endif;
                update SFL1;

        endsl;

    enddo;

    return *off;
end-proc  AUTLPGM_ProcessS1;


//=========================================================
dcl-proc  AUTLPGM_LoadS1;
    dcl-pi  *n;
        in_filter  likeds(filter) const options(*nopass : *omit);
    end-pi;

    dcl-ds filter  qualified;
        library    char(10);
        table      char(10);
        authList   char(10);
        status     char(10);
    end-ds;
    dcl-s  checkFilter  ind;

    dcl-ds publicAuth qualified;
        authority   char(10);
        source      char(10);
    end-ds;


    if %parms >= %parmnum(in_filter)
    and %addr(in_filter) <> *null
    and in_filter <> *blanks;
        filter = in_filter;
        checkFilter = *on;
    endif;

    s1_dsp = *off;
    s1_dspCtl = *off;
    write CTL1;
    s1_dspCtl = *on;
    clear rrn1;

    setll *loval AUTLTABLES;
    dou %eof(AUTLTABLES);
        read AUTLTABLES;
        if %eof(AUTLTABLES);
            iter;
        endif;

        if checkFilter;
            if  (filter.library <> *blanks
                and tracked_table_library <> filter.library)
            or  (filter.table <> *blanks
                and tracked_table <> filter.table)
            or  (filter.authList <> *blanks
                and authorization_list <> filter.authList)
            or  (filter.status <> *blanks
                and tracked_status <> filter.status);
                iter;
            endif;
        endif;

        clear SFL1;
        clear S1_Errors;
        s1tablib  = tracked_table_library;
        s1tabnam  = tracked_table;
        s1tabautl = authorization_list;
        s1status  = tracked_status;
        s1pubaut  = public_authority;
        s1pubsrc  = public_auth_source;
        s1actautl = GetFileAuthList(s1tablib : s1tabnam);
        publicAuth = GetFilePublicAuth(s1tablib : s1tabnam);
        s1actpub = publicAuth.authority;
        s1actsrc = publicAuth.source;

        if s1tabautl <> s1actautl;
            TABAUTL_Red = *on;
        endif;
        if s1pubaut <> s1actpub;
            PUBAUT_Red = *on;
        endif;
        if s1pubsrc <> s1actsrc;
            PUBSRC_Red = *on;
        endif;

        rrn1 += 1;
        write SFL1;

    enddo;

    if rrn1 > 0;
        S1_Dsp = *on;
        S1RcdNbr = 1;
    else;
        SendProgramMessage('No records found');
    endif;
    S1_FoldDrop = LESS_INFO;

end-proc  AUTLPGM_LoadS1;


//=========================================================
dcl-proc  AUTLPGM_AddNew;
    dcl-pi  *n   ind;
        out_lib  char(10) options(*nopass : *omit);
        out_file char(10) options(*nopass : *omit);
    end-pi;

    dcl-ds publicAuth qualified;
        authority   char(10);
        source      char(10);
    end-ds;

    clear WDW2;
    W2_ProtectFile = *off;

    dow '1';

        if not W2_ProtectFile;
            W2_MSG = 'Enter Lib/File and press <Enter>';
        endif;

        write MSGSFLC;
        exfmt WDW2;

        clear W2_MSG;
        clear W2_Errors;
        ClearProgramMessages();

        if keyPressed = F3
        or keyPressed = F12;
            leave;
        endif;

        if keyPressed = Enter;
            // If we're editing the LIBRARY and FILE
            if not W2_ProtectFile;
                select;
                    when W2TABLIB = *blanks;
                        SendProgramMessage('Library is required');
                        W2_Tablib_ERR = *on;

                    when not LibraryExists(W2TABLIB);
                        SendProgramMessage('Library name is not valid');
                        W2_Tablib_ERR = *on;

                    when W2TABNAM = *blanks;
                        SendProgramMessage('Table name is required');
                        W2_Tabnam_ERR = *on;

                    when not TableExists(W2TABLIB : W2TABNAM);
                        SendProgramMessage('Table name is not valid');
                        W2_Tabnam_ERR = *on;

                    other;
                        W2_ProtectFile = *on;
                endsl;

            // If we're editing the AUTL, PUBLIC Auth, and SOURCE
            else;
                if AUTLPGM_ValidateAuth(
                    W2TABLIB : W2TABNAM : W2TABAUTL : W2PUBAUT : W2PUBSRC
                );

                    Exec SQL
                        INSERT INTO pbehr.authl_tracked_tables
                        ( tracked_table_library
                        , tracked_table
                        , authorization_list
                        , public_authority
                        , public_auth_source
                        )
                        VALUES
                        ( :W2TABLIB
                        , :W2TABNAM
                        , :W2TABAUTL
                        , :W2PUBAUT
                        , :W2PUBSRC
                        );

                    if sqlcode = 0;

                        // Now that we've added the row, update the status
                        // to "pending" or "complete"
                        if AUTLPGM_UpdateStatus(
                            W2TABLIB : W2TABNAM : W2TABAUTL : W2PUBAUT : W2PUBSRC
                        );
                            SendProgramMessage('Row added');
                        else;
                            SendProgramMessage(
                                'Row added; status may not be set correctly'
                            );
                        endif;


                        // Send back the LIB and FILE name so we can filter the subfile
                        if %parms >= %parmnum(out_lib)
                        and %addr(out_lib) <> *null;
                            out_lib = W2TABLIB;
                        endif;
                        if %parms >= %parmnum(out_file)
                        and %addr(out_file) <> *null;
                            out_file = W2TABNAM;
                        endif;

                    else;
                        SendProgramMessage(
                            'Row not added: SQL Code "' + %char(sqlcode) + '"'
                        );
                    endif;

                    leave;
                endif;
            endif;
        endif;
    enddo;

    return *ON;
end-proc  AUTLPGM_AddNew;



//=========================================================
dcl-proc  AUTLPGM_Edit;
    dcl-pi  *n   ind;
        in_lib   char(10)  const;
        in_file  char(10)  const;
        inout_autl  char(10);
        inout_pub   char(10);
        inout_src   char(10);
        out_status  char(10);
    end-pi;

    dcl-s  qualFile   varchar(21);
    dcl-s  success    ind;
    dcl-s  newStatus  char(10);

    W2TABLIB = in_lib;
    W2TABNAM = in_file;
    W2TABAUTL = inout_autl;
    W2PUBAUT = inout_pub;
    W2PUBSRC = inout_src;
    W2_ProtectFile = *on;
    qualFile = %trim(in_lib) + '/' + in_file;

    dow '1';

        write MSGSFLC;
        exfmt WDW2;

        clear W2_MSG;
        clear W2_Errors;
        ClearProgramMessages();

        if keyPressed = F3
        or keyPressed = F12;
            leave;
        endif;

        if keyPressed = Enter;
            if AUTLPGM_ValidateAuth(
                W2TABLIB : W2TABNAM : W2TABAUTL : W2PUBAUT : W2PUBSRC
            );

                Exec SQL
                    UPDATE pbehr.authl_tracked_tables
                    SET
                      authorization_list = :W2TABAUTL
                    , public_authority = :W2PUBAUT
                    , public_auth_source = :W2PUBSRC
                    WHERE
                      tracked_table_library = :W2TABLIB
                      AND tracked_table = :W2TABNAM
                    ;

                if sqlcode = 0;

                    // Send back the new values to update the subfile
                    inout_autl = W2TABAUTL;
                    inout_pub = W2PUBAUT;
                    inout_src = W2PUBSRC;

                    // Update the status to "pending" or "complete"
                    if AUTLPGM_UpdateStatus(
                        W2TABLIB : W2TABNAM : W2TABAUTL : W2PUBAUT : W2PUBSRC : newStatus
                    );
                        success = *on;
                        out_status = newStatus;
                    else;
                        SendProgramMessage('Row updated; status not set');
                    endif;

                else;
                    SendProgramMessage(
                        qualFile + ' not modified SQLCOD "' + %char(sqlcode) + '"'
                    );
                endif;

                leave;
            endif;
        endif;
    enddo;

    return success;
end-proc  AUTLPGM_Edit;


//=========================================================
dcl-proc  AUTLPGM_UpdateStatus;
    dcl-pi  *n   ind;
        in_lib        char(10) const;
        in_file       char(10) const;
        in_authList   char(10) const;
        in_publicAuth char(10) const;
        in_authSource char(10) const;
        out_status    char(10) options(*nopass : *omit);
    end-pi;

    dcl-s  currentAutl  char(10);
    dcl-ds currentAuth qualified;
        authority   char(10);
        source      char(10);
    end-ds;
    dcl-s  status   char(10);

    currentAuth = GetFilePublicAuth(in_lib : in_file);
    currentAutl = GetFileAuthList(in_lib : in_file);

    // Compare the requested authority with the actual authority.
    // If they don't match, update status to "pending".
    if in_authList <> currentAutl
    or in_publicAuth <> currentAuth.authority
    or in_authSource <> currentAuth.source;
        status = 'pending';

    // If they do match, mark it as "complete"
    else;
        status = 'complete';

    endif;

    Exec SQL
        UPDATE pbehr.authl_tracked_tables
        SET status = :status
        WHERE tracked_table_library = :in_lib
        AND tracked_table = :in_file;

    if %parms >= %parmnum(out_status)
    and %addr(out_status) <> *null;
        out_status = status;
    endif;

    return (sqlcode = 0);

end-proc  AUTLPGM_UpdateStatus;


//=========================================================
dcl-proc  AUTLPGM_ValidateAuth;
    dcl-pi  *n   ind;
        in_lib        char(10) const;
        in_file       char(10) const;
        in_authList   char(10);   // This parm can be changed if *CURRENT is used
        in_publicAuth char(10) const;
        in_authSource char(10) const;
    end-pi;

    dcl-s  isValid  ind  inz(*on);
    dcl-s  currentAutl  char(10);

    select;

        when in_authList = '?';
            SendProgramMessage(
                'AuthList can be name of an authorization list, or *CURRENT'
            );
            isValid = *off;

        when in_publicAuth = '?';
            SendProgramMessage(
                '*PUBLIC authority can be "*EXCLUDE" "*USE" "*CHANGE" or "*ALL"'
            );
            isValid = *off;

        when in_authSource = '?';
            SendProgramMessage(
                'Authority source can be "*FILE" or "*AUTL"'
            );
            isValid = *off;

        when in_authList <> *blanks
         and in_authList <> '*CURRENT'
         and not AuthListExists(in_authList);
            SendProgramMessage('Authorization list is not valid');
            W2_Tabautl_ERR = *on;
            isValid = *off;

        when in_authList = '*CURRENT';
            currentAutl = GetFileAuthList(in_lib : in_file);
            if currentAutl = *blanks;
                SendProgramMessage('*CURRENT is not valid for this file');
                W2_Tabautl_ERR = *on;
            else;
                in_authList = currentAutl;
            endif;
            isValid = *off;

        when in_authSource <> '*FILE'
         and in_authSource <> '*AUTL'
         and in_authSource <> *blanks;
            SendProgramMessage(
                'Source must be "*FILE" or "*AUTL"'
            );
            W2_PubSrc_ERR = *on;
            isValid = *off;

        when in_publicAuth <> '*EXCLUDE'
         and in_publicAuth <> '*USE'
         and in_publicAuth <> '*CHANGE'
         and in_publicAuth <> '*ALL'
         and in_publicAuth <> *blanks;
            SendProgramMessage(
                'Authority must be "*EXCLUDE" "*USE" "*CHANGE" or "*ALL"'
            );
            W2_PubAut_ERR = *on;
            isValid = *off;

        // If you want *PUBLIC authority to come from *AUTL
        // the file must have an authoritzation list
        when in_authSource = '*AUTL'
         and in_authList = *blanks;
            SendProgramMessage(
                'Authorization list required for *AUTL source'
            );
            W2_Tabautl_ERR = *on;
            isValid = *off;

        // If you want *PUBLIC authority to come from *AUTL
        // you must NOT provide a specific *PUBLIC authority
        when in_authSource = '*AUTL'
         and in_publicAuth <> *blanks;
            SendProgramMessage(
                '*Public authority is not allowed for *AUTL source'
            );
            W2_PubAut_ERR = *on;
            isValid = *off;

        // If you want *PUBLIC authority to come from *FILE
        // you must provide a specific *PUBLIC authority
        when in_authSource = '*FILE'
         and in_publicAuth = *blanks;
            SendProgramMessage(
                'You must provide a *Public authority for *FILE source'
            );
            W2_PubAut_ERR = *on;
            isValid = *off;

        // If you are removing the authorization list, you
        // must provide a *PUBLIC authority and *FILE source
        when in_authList = *blanks
         and (in_authSource <> '*FILE' or in_publicAuth = *blanks);
            SendProgramMessage(
                '*Public authority and source *FILE required with no AUTL'
            );
            W2_PubAut_ERR = *on;
            W2_PubSrc_ERR = *on;
            isValid = *off;

    endsl;

    return isValid;

end-proc  AUTLPGM_ValidateAuth;

/copy *LIBL/AUTHLIST,AUTLMSGCPY

