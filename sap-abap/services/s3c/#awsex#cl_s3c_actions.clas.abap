" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS /awsex/cl_s3c_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS create_job
      IMPORTING
                !iv_account_id        TYPE /aws1/s3caccountid
                !iv_role_arn          TYPE /aws1/s3ciamrolearn
                !iv_manifest_location TYPE string
                !iv_report_bucket_arn TYPE /aws1/s3cs3bucketarnstring
      EXPORTING
                !oo_result            TYPE REF TO /aws1/cl_s3ccreatejobresult
      RAISING   /aws1/cx_rt_generic.
    METHODS update_job_priority
      IMPORTING
                !iv_account_id TYPE /aws1/s3caccountid
                !iv_job_id     TYPE /aws1/s3cjobid
                !iv_priority   TYPE /aws1/s3cjobpriority
      RAISING   /aws1/cx_rt_generic.
    METHODS update_job_status
      IMPORTING
                !iv_account_id TYPE /aws1/s3caccountid
                !iv_job_id     TYPE /aws1/s3cjobid
                !iv_status     TYPE /aws1/s3crequestedjobstatus
      RAISING   /aws1/cx_rt_generic.
    METHODS describe_job
      IMPORTING
                !iv_account_id TYPE /aws1/s3caccountid
                !iv_job_id     TYPE /aws1/s3cjobid
      EXPORTING
                !oo_result     TYPE REF TO /aws1/cl_s3cdescribejobresult
      RAISING   /aws1/cx_rt_generic.
    METHODS get_job_tagging
      IMPORTING
                !iv_account_id TYPE /aws1/s3caccountid
                !iv_job_id     TYPE /aws1/s3cjobid
      EXPORTING
                !oo_result     TYPE REF TO /aws1/cl_s3cgetjobtagresult
      RAISING   /aws1/cx_rt_generic.
    METHODS put_job_tagging
      IMPORTING
                !iv_account_id TYPE /aws1/s3caccountid
                !iv_job_id     TYPE /aws1/s3cjobid
                !it_tags       TYPE /aws1/cl_s3cs3tag=>tt_s3tagset
      RAISING   /aws1/cx_rt_generic.
    METHODS list_jobs
      IMPORTING
                !iv_account_id TYPE /aws1/s3caccountid
                !it_statuses   TYPE /aws1/cl_s3cjobstatuslist_w=>tt_jobstatuslist
      EXPORTING
                !oo_result     TYPE REF TO /aws1/cl_s3clistjobsresult
      RAISING   /aws1/cx_rt_generic.
    METHODS delete_job_tagging
      IMPORTING
                !iv_account_id TYPE /aws1/s3caccountid
                !iv_job_id     TYPE /aws1/s3cjobid
      RAISING   /aws1/cx_rt_generic.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /AWSEX/CL_S3C_ACTIONS IMPLEMENTATION.


  METHOD create_job.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.create_job]
    TRY.
        " Extract bucket name and manifest key from location
        DATA(lv_manifest_arn) = CONV /aws1/s3cs3keyarnstring( iv_manifest_location ).
        DATA lv_bucket TYPE string.
        DATA lv_key TYPE string.
        
        SPLIT iv_manifest_location AT ':::' INTO DATA(lv_prefix) lv_bucket.
        SPLIT lv_bucket AT '/' INTO lv_bucket lv_key.
        
        " Get manifest ETag
        DATA(lo_s3) = /aws1/cl_s3_factory=>create( lo_session ).
        DATA(lo_manifest_obj) = lo_s3->headobject(
          iv_bucket = CONV /aws1/s3_bucketname( lv_bucket )
          iv_key = CONV /aws1/s3_objectkey( lv_key ) ).
        DATA(lv_etag) = lo_manifest_obj->get_etag( ).
        REPLACE ALL OCCURRENCES OF '"' IN lv_etag WITH ''.
        
        " Create tag set for the job
        DATA lt_tags TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
        APPEND NEW /aws1/cl_s3cs3tag(
          iv_key = 'BatchTag'
          iv_value = 'BatchValue' ) TO lt_tags.
        
        " Create the batch job
        oo_result = lo_s3c->createjob(
          iv_accountid = iv_account_id
          iv_confirmationrequired = abap_true
          io_operation = NEW /aws1/cl_s3cjoboperation(
            io_s3putobjecttagging = NEW /aws1/cl_s3cs3setobjecttagop(
              it_tagset = lt_tags ) )
          io_report = NEW /aws1/cl_s3cjobreport(
            iv_bucket = iv_report_bucket_arn
            iv_format = 'Report_CSV_20180820'
            iv_enabled = abap_true
            iv_prefix = 'batch-op-reports'
            iv_reportscope = 'AllTasks' )
          io_manifest = NEW /aws1/cl_s3cjobmanifest(
            io_spec = NEW /aws1/cl_s3cjobmanifestspec(
              iv_format = 'S3BatchOperations_CSV_20180820'
              it_fields = VALUE /aws1/cl_s3cjobmanifestfield00=>tt_jobmanifestfieldlist(
                ( NEW /aws1/cl_s3cjobmanifestfield00( iv_value = 'Bucket' ) )
                ( NEW /aws1/cl_s3cjobmanifestfield00( iv_value = 'Key' ) ) ) )
            io_location = NEW /aws1/cl_s3cjobmanifestloc(
              iv_objectarn = lv_manifest_arn
              iv_etag = CONV /aws1/s3cnonemptymaxlength2500( lv_etag ) ) )
          iv_priority = 10
          iv_rolearn = iv_role_arn
          iv_description = 'Batch job for tagging objects' ).
        
        DATA(lv_job_id) = oo_result->get_jobid( ).
        MESSAGE |The Job id is { lv_job_id }| TYPE 'I'.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_req).
        MESSAGE lo_bad_req->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cidempotencyex INTO DATA(lo_idemp).
        MESSAGE lo_idemp->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_message( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.create_job]
  ENDMETHOD.


  METHOD update_job_priority.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.update_job_priority]
    TRY.
        " Get current job status first
        DATA(lo_job_desc) = lo_s3c->describejob(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id ).
        
        DATA(lv_current_status) = lo_job_desc->get_job( )->get_status( ).
        MESSAGE |Current job status: { lv_current_status }| TYPE 'I'.
        
        IF lv_current_status = 'Ready' OR lv_current_status = 'Suspended'.
          " Update the priority
          lo_s3c->updatejobpriority(
            iv_accountid = iv_account_id
            iv_jobid = iv_job_id
            iv_priority = iv_priority ).
          MESSAGE 'The job priority was updated' TYPE 'I'.
          
          " Try to activate the job if it's in Ready or Suspended state
          TRY.
              lo_s3c->updatejobstatus(
                iv_accountid = iv_account_id
                iv_jobid = iv_job_id
                iv_requestedjobstatus = 'Ready' ).
              MESSAGE 'Job activated successfully' TYPE 'I'.
            CATCH /aws1/cx_s3cjobstatusexception.
              MESSAGE 'Job priority was updated. Job may need manual activation.' TYPE 'I'.
          ENDTRY.
        ELSEIF lv_current_status = 'Active' OR lv_current_status = 'Completing'
            OR lv_current_status = 'Complete'.
          MESSAGE |Job is in '{ lv_current_status }' state - priority cannot be updated| TYPE 'I'.
        ELSE.
          MESSAGE |Job is in '{ lv_current_status }' state - priority update not allowed| TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_req).
        MESSAGE lo_bad_req->get_message( ) TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_message( ) TYPE 'I'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_message( ) TYPE 'I'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_message( ) TYPE 'I'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.update_job_priority]
  ENDMETHOD.


  METHOD update_job_status.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.update_job_status]
    TRY.
        " Get current job status first
        DATA(lo_job_desc) = lo_s3c->describejob(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id ).
        
        DATA(lv_current_status) = lo_job_desc->get_job( )->get_status( ).
        MESSAGE |Current job status: { lv_current_status }| TYPE 'I'.
        
        IF lv_current_status = 'Ready' OR lv_current_status = 'Suspended'
            OR lv_current_status = 'Active'.
          " Cancel the job
          lo_s3c->updatejobstatus(
            iv_accountid = iv_account_id
            iv_jobid = iv_job_id
            iv_requestedjobstatus = iv_status ).
          MESSAGE |Job { iv_job_id } status updated to { iv_status }| TYPE 'I'.
        ELSEIF lv_current_status = 'Completing' OR lv_current_status = 'Complete'.
          MESSAGE |Job is in '{ lv_current_status }' state - cannot be cancelled| TYPE 'I'.
        ELSE.
          MESSAGE |Job is in '{ lv_current_status }' state - cancel not allowed| TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_req).
        MESSAGE lo_bad_req->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cjobstatusexception INTO DATA(lo_job_status).
        MESSAGE lo_job_status->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_message( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.update_job_status]
  ENDMETHOD.


  METHOD describe_job.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.describe_job]
    TRY.
        oo_result = lo_s3c->describejob(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id ).
        
        DATA(lo_job) = oo_result->get_job( ).
        DATA(lv_job_id) = lo_job->get_jobid( ).
        DATA(lv_description) = lo_job->get_description( ).
        DATA(lv_status) = lo_job->get_status( ).
        DATA(lv_role_arn) = lo_job->get_rolearn( ).
        DATA(lv_priority) = lo_job->get_priority( ).
        
        DATA(lv_message) = |Job ID: { lv_job_id }, Status: { lv_status }|.
        IF lo_job->get_progresssummary( ) IS BOUND.
          DATA(lo_progress) = lo_job->get_progresssummary( ).
          DATA(lv_total) = lo_progress->get_totalnumberoftasks( ).
          DATA(lv_succeeded) = lo_progress->get_numberoftaskssucceeded( ).
          DATA(lv_failed) = lo_progress->get_numberoftasksfailed( ).
          lv_message = |{ lv_message }, Total: { lv_total }, Succeeded: { lv_succeeded }, Failed: { lv_failed }|.
        ENDIF.
        MESSAGE lv_message TYPE 'I'.
      CATCH /aws1/cx_s3cbadrequestex INTO DATA(lo_bad_req).
        MESSAGE lo_bad_req->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_message( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.describe_job]
  ENDMETHOD.


  METHOD get_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.get_job_tagging]
    TRY.
        oo_result = lo_s3c->getjobtagging(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id ).
        
        DATA(lt_tags) = oo_result->get_tags( ).
        IF lt_tags IS NOT INITIAL.
          MESSAGE |Found { lines( lt_tags ) } tag(s) for job { iv_job_id }| TYPE 'I'.
        ELSE.
          MESSAGE |No tags found for job ID: { iv_job_id }| TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_message( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.get_job_tagging]
  ENDMETHOD.


  METHOD put_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.put_job_tagging]
    TRY.
        lo_s3c->putjobtagging(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id
          it_tags = it_tags ).
        MESSAGE |Additional tags were added to job { iv_job_id }| TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanytagsex INTO DATA(lo_too_many_tags).
        MESSAGE lo_too_many_tags->get_message( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.put_job_tagging]
  ENDMETHOD.


  METHOD list_jobs.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.list_jobs]
    TRY.
        oo_result = lo_s3c->listjobs(
          iv_accountid = iv_account_id
          it_jobstatuses = it_statuses ).
        
        DATA(lt_jobs) = oo_result->get_jobs( ).
        LOOP AT lt_jobs INTO DATA(lo_job).
          DATA(lv_job_id) = lo_job->get_jobid( ).
          DATA(lv_priority) = lo_job->get_priority( ).
          MESSAGE |Job ID: { lv_job_id }, Priority: { lv_priority }| TYPE 'I'.
        ENDLOOP.
        
        IF lt_jobs IS INITIAL.
          MESSAGE 'No jobs found' TYPE 'I'.
        ENDIF.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinvalidnexttokenex INTO DATA(lo_invalid_token).
        MESSAGE lo_invalid_token->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cinvalidrequestex INTO DATA(lo_invalid_req).
        MESSAGE lo_invalid_req->get_message( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.list_jobs]
  ENDMETHOD.


  METHOD delete_job_tagging.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_s3c) = /aws1/cl_s3c_factory=>create( lo_session ).

    " snippet-start:[s3c.abapv1.delete_job_tagging]
    TRY.
        lo_s3c->deletejobtagging(
          iv_accountid = iv_account_id
          iv_jobid = iv_job_id ).
        MESSAGE |Successfully deleted tagging for job { iv_job_id }| TYPE 'I'.
      CATCH /aws1/cx_s3cinternalserviceex INTO DATA(lo_internal).
        MESSAGE lo_internal->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3cnotfoundexception INTO DATA(lo_not_found).
        MESSAGE lo_not_found->get_message( ) TYPE 'E'.
      CATCH /aws1/cx_s3ctoomanyrequestsex INTO DATA(lo_too_many).
        MESSAGE lo_too_many->get_message( ) TYPE 'E'.
    ENDTRY.
    " snippet-end:[s3c.abapv1.delete_job_tagging]
  ENDMETHOD.
ENDCLASS.
