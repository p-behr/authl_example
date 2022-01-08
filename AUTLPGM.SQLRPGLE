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
    S1_Errors          char(3)  pos(10);
      TABAUTL_Error    ind      pos(10);
      PUBAUT_Error     ind      pos(11);
      PUBSRC_Error     ind      pos(12);
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

    endsl;

enddo;


    *inlr = *on;
    return;



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
        tablib  = tracked_table_library;
        tabnam  = tracked_table;
        tabautl = authorization_list;
        status  = tracked_status;
        pubaut  = public_authority;
        pubsrc  = public_auth_source;
        actautl = GetFileAuthList(tablib : tabnam);
        publicAuth = GetFilePublicAuth(tablib : tabnam);
        actpub = publicAuth.authority;
        actsrc = publicAuth.source;

        if tabautl <> actautl;
            TABAUTL_Error = *on;
        endif;
        if pubaut <> actpub;
            PUBAUT_Error = *on;
        endif;
        if pubsrc <> actsrc;
            PUBSRC_Error = *on;
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
        // Returns the LIB and FILE so that we can filter
        // the subfile to the newly added file.
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
            if not W2_ProtectFile;
                select;
                    when TABLIB = *blanks;
                        SendProgramMessage('Library is required');
                        W2_Tablib_ERR = *on;

                    when not LibraryExists(TABLIB);
                        SendProgramMessage('Library name is not valid');
                        W2_Tablib_ERR = *on;

                    when TABNAM = *blanks;
                        SendProgramMessage('Table name is required');
                        W2_Tabnam_ERR = *on;

                    when not TableExists(TABLIB : TABNAM);
                        SendProgramMessage('Table name is not valid');
                        W2_Tabnam_ERR = *on;

                    other;
                        W2_ProtectFile = *on;
                endsl;
            else;
                select;
                    when TABAUTL <> *blanks
                     and not AuthListExists(TABAUTL);
                        SendProgramMessage('Authorization list is not valid');
                        W2_Tabautl_ERR = *on;

                    when PUBAUT = *blanks;
                        SendProgramMessage('Public authority is required');
                        W2_PubAut_ERR = *on;

                    when PUBAUT <> '*EXCLUDE'
                     and PUBAUT <> '*USE'
                     and PUBAUT <> '*CHANGE'
                     and PUBAUT <> '*ALL';
                        SendProgramMessage('Authority must be +
                                           "*EXCLUDE" "*USE" "*CHANGE" or "*ALL"');
                        W2_PubAut_ERR = *on;

                    when PUBSRC = *blanks;
                        SendProgramMessage('Public auth source is required');
                        W2_PubSrc_ERR = *on;

                    when PUBSRC <> '*FILE'
                     and PUBSRC <> '*AUTL';
                        SendProgramMessage('Source must be "*FILE" or "*AUTL"');
                        W2_PubSrc_ERR = *on;

                    when PUBSRC = '*AUTL'
                     and TABAUTL = *blanks;
                        SendProgramMessage('No auth list; source must be "*FILE"');
                        W2_PubSrc_ERR = *on;

                    other;

                        Exec SQL
                            INSERT INTO pbehr.authl_tracked_tables
                            ( tracked_table_library
                            , tracked_table
                            , authorization_list
                            , public_authority
                            , public_auth_source
                            )
                            VALUES
                            ( :TABLIB
                            , :TABNAM
                            , :TABAUTL
                            , :PUBAUT
                            , :PUBSRC
                            );

                        if sqlcode = 0;
                            publicAuth = GetFilePublicAuth(tablib : tabnam);
                            if tabautl <> GetFileAuthList(tablib : tabnam)
                            or pubaut <> publicAuth.authority
                            or pubsrc <> publicAuth.source;
                                Exec SQL
                                  UPDATE pbehr.authl_tracked_tables
                                  SET status = 'pending'
                                  WHERE tracked_table_library = :tablib
                                    AND tracked_table = :tabnam;
                            endif;
                        endif;

                        leave;
                endsl;
            endif;

        endif;

    enddo;

    return *ON;
end-proc  AUTLPGM_AddNew;


/copy *LIBL/AUTHLIST,AUTLMSGCPY
