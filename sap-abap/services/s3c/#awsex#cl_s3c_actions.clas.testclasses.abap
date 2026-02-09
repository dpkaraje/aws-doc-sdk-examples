" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0
CLASS ltc_awsex_cl_s3c_actions DEFINITION DEFERRED.
CLASS /awsex/cl_s3c_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_s3c_actions.

CLASS ltc_awsex_cl_s3c_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA av_account_id TYPE /aws1/s3caccountid.
    CLASS-DATA av_bucket_name TYPE /aws1/s3_bucketname.
    CLASS-DATA av_role_arn TYPE /aws1/s3ciamrolearn.
    CLASS-DATA av_role_name TYPE /aws1/iamrolenametype.
    CLASS-DATA av_policy_arn TYPE /aws1/iamarntype.
    CLASS-DATA av_policy_name TYPE /aws1/iampolicynametype.
    CLASS-DATA av_manifest_location TYPE string.
    CLASS-DATA av_job_id TYPE /aws1/s3cjobid.
    CLASS-DATA av_job_id_for_priority TYPE /aws1/s3cjobid.
    CLASS-DATA av_job_id_for_tags TYPE /aws1/s3cjobid.
    CLASS-DATA av_job_id_for_cancel TYPE /aws1/s3cjobid.

    CLASS-DATA ao_s3 TYPE REF TO /aws1/if_s3.
    CLASS-DATA ao_s3c TYPE REF TO /aws1/if_s3c.
    CLASS-DATA ao_iam TYPE REF TO /aws1/if_iam.
    CLASS-DATA ao_sts TYPE REF TO /aws1/if_sts.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_s3c_actions TYPE REF TO /awsex/cl_s3c_actions.

    METHODS create_job FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS update_job_priority FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS describe_job FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS get_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS put_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS list_jobs FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS delete_job_tagging FOR TESTING RAISING /aws1/cx_rt_generic.
    METHODS update_job_status FOR TESTING RAISING /aws1/cx_rt_generic.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.
    
    CLASS-METHODS wait_for_job_status
      IMPORTING
                iv_job_id        TYPE /aws1/s3cjobid
                iv_target_status TYPE string
                iv_timeout_sec   TYPE i DEFAULT 300
      RETURNING VALUE(rv_success) TYPE abap_bool
      RAISING   /aws1/cx_rt_generic.
      
    CLASS-METHODS create_test_job
      RETURNING VALUE(rv_job_id) TYPE /aws1/s3cjobid
      RAISING   /aws1/cx_rt_generic.
ENDCLASS.

CLASS ltc_awsex_cl_s3c_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_s3 = /aws1/cl_s3_factory=>create( ao_session ).
    ao_s3c = /aws1/cl_s3c_factory=>create( ao_session ).
    ao_iam = /aws1/cl_iam_factory=>create( ao_session ).
    ao_sts = /aws1/cl_sts_factory=>create( ao_session ).
    ao_s3c_actions = NEW /awsex/cl_s3c_actions( ).

    " Get account ID
    DATA(lo_identity) = ao_sts->getcalleridentity( ).
    av_account_id = lo_identity->get_account( ).

    " Create bucket for batch operations
    av_bucket_name = |sap-abap-s3c-batch-{ av_account_id }|.
    
    TRY.
        /awsex/cl_utils=>create_bucket( iv_bucket = av_bucket_name io_s3 = ao_s3 io_session = ao_session ).
      CATCH /aws1/cx_s3_bktalrdyownedbyyou.
        " Bucket already exists, clean and recreate
        TRY.
            /awsex/cl_utils=>cleanup_bucket( iv_bucket = av_bucket_name io_s3 = ao_s3 ).
            /awsex/cl_utils=>create_bucket( iv_bucket = av_bucket_name io_s3 = ao_s3 io_session = ao_session ).
          CATCH /aws1/cx_rt_generic.
            cl_abap_unit_assert=>fail( msg = |Failed to create bucket { av_bucket_name }| ).
        ENDTRY.
    ENDTRY.

    " Tag bucket with convert_test tag
    DATA lt_bucket_tags TYPE /aws1/cl_s3_tag=>tt_tagset.
    APPEND NEW /aws1/cl_s3_tag( iv_key = 'convert_test' iv_value = 'true' ) TO lt_bucket_tags.
    ao_s3->putbuckettagging( 
      iv_bucket = av_bucket_name 
      io_tagging = NEW /aws1/cl_s3_tagging( it_tagset = lt_bucket_tags ) ).

    " Create test files in bucket
    DATA lt_files TYPE string_table.
    lt_files = VALUE #( ( |test-file-1.txt| )
                        ( |test-file-2.txt| )
                        ( |test-file-3.txt| ) ).

    LOOP AT lt_files INTO DATA(lv_file).
      ao_s3->putobject(
        iv_bucket = av_bucket_name
        iv_key = CONV /aws1/s3_objectkey( lv_file )
        iv_body = CONV /aws1/s3_streamingblob( |Content for { lv_file }| ) ).
    ENDLOOP.

    " Create manifest file
    DATA lv_manifest_content TYPE string.
    lv_manifest_content = |{ av_bucket_name },test-file-1.txt\n| &&
                          |{ av_bucket_name },test-file-2.txt\n| &&
                          |{ av_bucket_name },test-file-3.txt|.

    ao_s3->putobject(
      iv_bucket = av_bucket_name
      iv_key = 'job-manifest.csv'
      iv_body = CONV /aws1/s3_streamingblob( lv_manifest_content ) ).

    " Build manifest location ARN
    av_manifest_location = |arn:aws:s3:::{ av_bucket_name }/job-manifest.csv|.

    " Create IAM role for S3 Batch Operations
    DATA lv_uuid TYPE sysuuid_c32.
    TRY.
        CALL FUNCTION 'GUID_CREATE'
          IMPORTING
            ev_guid_32 = lv_uuid.
      CATCH cx_root.
        lv_uuid = /awsex/cl_utils=>get_random_string( ).
    ENDTRY.
    
    av_role_name = |S3BatchRole{ lv_uuid(18) }|.
    
    " Trust policy for S3 Batch Operations
    DATA(lv_trust_policy) = '{ ' &&
      '"Version":"2012-10-17",' &&
      '"Statement":[{ ' &&
      '"Effect":"Allow",' &&
      '"Principal":{"Service":"batchoperations.s3.amazonaws.com"},' &&
      '"Action":"sts:AssumeRole"' &&
      '}]' &&
      '}'.

    " Create role
    DATA(lo_role) = ao_iam->createrole(
      iv_rolename = av_role_name
      iv_assumerolepolicydocument = lv_trust_policy
      iv_description = 'Role for S3 Batch Operations test' ).
    av_role_arn = lo_role->get_role( )->get_arn( ).

    " Tag the role with convert_test
    DATA lt_role_tags TYPE /aws1/cl_iamtag=>tt_taglisttype.
    APPEND NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) TO lt_role_tags.
    ao_iam->tagrole(
      iv_rolename = av_role_name
      it_tags = lt_role_tags ).

    " Create and attach comprehensive policy for S3 Batch Operations
    DATA(lv_policy_doc) = '{ ' &&
      '"Version":"2012-10-17",' &&
      '"Statement":[' &&
      '{ ' &&
      '"Effect":"Allow",' &&
      '"Action":["s3:GetObject","s3:GetObjectVersion","s3:PutObject",' &&
      '"s3:PutObjectTagging","s3:GetObjectTagging","s3:PutObjectVersionTagging",' &&
      '"s3:GetObjectVersionTagging","s3:DeleteObjectTagging","s3:DeleteObjectVersionTagging"],' &&
      '"Resource":"arn:aws:s3:::' && av_bucket_name && '/*"' &&
      '},{ ' &&
      '"Effect":"Allow",' &&
      '"Action":["s3:GetBucketLocation","s3:ListBucket","s3:ListBucketVersions",' &&
      '"s3:GetBucketTagging","s3:PutBucketTagging"],' &&
      '"Resource":"arn:aws:s3:::' && av_bucket_name && '"' &&
      '},{ ' &&
      '"Effect":"Allow",' &&
      '"Action":["s3:PutObject","s3:GetObject"],' &&
      '"Resource":"arn:aws:s3:::' && av_bucket_name && '/batch-op-reports/*"' &&
      '}]' &&
      '}'.

    DATA lv_policy_uuid TYPE sysuuid_c32.
    TRY.
        CALL FUNCTION 'GUID_CREATE'
          IMPORTING
            ev_guid_32 = lv_policy_uuid.
      CATCH cx_root.
        lv_policy_uuid = /awsex/cl_utils=>get_random_string( ).
    ENDTRY.
    
    DATA(lv_policy_name) = |S3BatchPol{ lv_policy_uuid(18) }|.
    av_policy_name = lv_policy_name.
    DATA(lo_policy) = ao_iam->createpolicy(
      iv_policyname = av_policy_name
      iv_policydocument = lv_policy_doc
      iv_description = 'Policy for S3 Batch Operations test' ).
    av_policy_arn = lo_policy->get_policy( )->get_arn( ).

    " Tag the policy
    DATA lt_policy_tags TYPE /aws1/cl_iamtag=>tt_taglisttype.
    APPEND NEW /aws1/cl_iamtag( iv_key = 'convert_test' iv_value = 'true' ) TO lt_policy_tags.
    ao_iam->tagpolicy(
      iv_policyarn = av_policy_arn
      it_tags = lt_policy_tags ).

    " Attach policy to role
    ao_iam->attachrolepolicy(
      iv_rolename = av_role_name
      iv_policyarn = av_policy_arn ).

    " Wait for IAM role to propagate
    WAIT UP TO 15 SECONDS.
  ENDMETHOD.

  METHOD class_teardown.
    " Cancel all running jobs
    DATA lt_job_ids TYPE STANDARD TABLE OF /aws1/s3cjobid.
    IF av_job_id IS NOT INITIAL.
      APPEND av_job_id TO lt_job_ids.
    ENDIF.
    IF av_job_id_for_priority IS NOT INITIAL.
      APPEND av_job_id_for_priority TO lt_job_ids.
    ENDIF.
    IF av_job_id_for_tags IS NOT INITIAL.
      APPEND av_job_id_for_tags TO lt_job_ids.
    ENDIF.
    IF av_job_id_for_cancel IS NOT INITIAL.
      APPEND av_job_id_for_cancel TO lt_job_ids.
    ENDIF.

    LOOP AT lt_job_ids INTO DATA(lv_job_id).
      TRY.
          DATA(lo_job) = ao_s3c->describejob(
            iv_accountid = av_account_id
            iv_jobid = lv_job_id ).
          
          DATA(lv_status) = lo_job->get_job( )->get_status( ).
          IF lv_status = 'Ready' OR lv_status = 'Active' OR lv_status = 'Suspended'.
            ao_s3c->updatejobstatus(
              iv_accountid = av_account_id
              iv_jobid = lv_job_id
              iv_requestedjobstatus = 'Cancelled' ).
          ENDIF.
        CATCH /aws1/cx_rt_generic.
      ENDTRY.
    ENDLOOP.

    " Clean up S3 bucket
    TRY.
        /awsex/cl_utils=>cleanup_bucket( iv_bucket = av_bucket_name io_s3 = ao_s3 ).
      CATCH /aws1/cx_rt_generic.
    ENDTRY.

    " Clean up IAM resources
    IF av_role_name IS NOT INITIAL AND av_policy_arn IS NOT INITIAL.
      TRY.
          " Detach policy from role
          ao_iam->detachrolepolicy(
            iv_rolename = av_role_name
            iv_policyarn = av_policy_arn ).
        CATCH /aws1/cx_rt_generic.
      ENDTRY.

      TRY.
          " Delete policy
          ao_iam->deletepolicy( iv_policyarn = av_policy_arn ).
        CATCH /aws1/cx_rt_generic.
      ENDTRY.

      TRY.
          " Delete role
          ao_iam->deleterole( iv_rolename = av_role_name ).
        CATCH /aws1/cx_rt_generic.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD wait_for_job_status.
    DATA lv_elapsed TYPE i.
    DATA lv_start_time TYPE timestamp.
    DATA lv_current_time TYPE timestamp.
    
    GET TIME STAMP FIELD lv_start_time.
    rv_success = abap_false.
    
    DO.
      DATA(lo_result) = ao_s3c->describejob(
        iv_accountid = av_account_id
        iv_jobid = iv_job_id ).
      
      DATA(lv_current_status) = lo_result->get_job( )->get_status( ).
      
      IF lv_current_status = iv_target_status.
        rv_success = abap_true.
        RETURN.
      ENDIF.
      
      " Check for terminal states
      IF lv_current_status = 'Failed' OR lv_current_status = 'Cancelled'
          OR lv_current_status = 'Complete'.
        IF lv_current_status <> iv_target_status.
          " Reached different terminal state
          rv_success = abap_false.
        ELSE.
          rv_success = abap_true.
        ENDIF.
        RETURN.
      ENDIF.
      
      " Check timeout
      GET TIME STAMP FIELD lv_current_time.
      lv_elapsed = lv_current_time - lv_start_time.
      IF lv_elapsed > iv_timeout_sec.
        rv_success = abap_false.
        RETURN.
      ENDIF.
      
      WAIT UP TO 5 SECONDS.
    ENDDO.
  ENDMETHOD.

  METHOD create_test_job.
    " Create a new job for testing
    DATA lt_tags TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
    APPEND NEW /aws1/cl_s3cs3tag(
      iv_key = 'TestTag'
      iv_value = 'TestValue' ) TO lt_tags.
    
    " Get manifest ETag
    DATA(lo_manifest_obj) = ao_s3->headobject(
      iv_bucket = av_bucket_name
      iv_key = 'job-manifest.csv' ).
    DATA(lv_etag) = lo_manifest_obj->get_etag( ).
    REPLACE ALL OCCURRENCES OF '"' IN lv_etag WITH ''.
    
    DATA(lo_result) = ao_s3c->createjob(
      iv_accountid = av_account_id
      iv_confirmationrequired = abap_true
      io_operation = NEW /aws1/cl_s3cjoboperation(
        io_s3putobjecttagging = NEW /aws1/cl_s3cs3setobjecttagop(
          it_tagset = lt_tags ) )
      io_report = NEW /aws1/cl_s3cjobreport(
        iv_bucket = CONV /aws1/s3cs3bucketarnstring( |arn:aws:s3:::{ av_bucket_name }| )
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
          iv_objectarn = CONV /aws1/s3cs3keyarnstring( av_manifest_location )
          iv_etag = CONV /aws1/s3cnonemptymaxlength2500( lv_etag ) ) )
      iv_priority = 10
      iv_rolearn = av_role_arn
      iv_description = 'Test batch job for tagging objects' ).
    
    rv_job_id = lo_result->get_jobid( ).
    
    " Wait for job to become Ready
    DATA(lv_success) = wait_for_job_status(
      iv_job_id = rv_job_id
      iv_target_status = 'Ready'
      iv_timeout_sec = 120 ).
      
    IF lv_success = abap_false.
      cl_abap_unit_assert=>fail( msg = |Job { rv_job_id } did not reach Ready status| ).
    ENDIF.
  ENDMETHOD.

  METHOD create_job.
    DATA lo_result TYPE REF TO /aws1/cl_s3ccreatejobresult.
    
    " Ensure all prerequisites are ready
    cl_abap_unit_assert=>assert_not_initial(
      act = av_account_id
      msg = 'Account ID must be set in class_setup' ).
    cl_abap_unit_assert=>assert_not_initial(
      act = av_role_arn
      msg = 'Role ARN must be set in class_setup' ).
    cl_abap_unit_assert=>assert_not_initial(
      act = av_manifest_location
      msg = 'Manifest location must be set in class_setup' ).
    
    " Test creating a job
    ao_s3c_actions->create_job(
      EXPORTING
        iv_account_id = av_account_id
        iv_role_arn = av_role_arn
        iv_manifest_location = av_manifest_location
        iv_report_bucket_arn = CONV /aws1/s3cs3bucketarnstring( |arn:aws:s3:::{ av_bucket_name }| )
      IMPORTING
        oo_result = lo_result ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Create job result should be bound' ).

    av_job_id = lo_result->get_jobid( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = av_job_id
      msg = 'Job ID should not be initial' ).

    " Wait for job to become Ready
    DATA(lv_success) = wait_for_job_status(
      iv_job_id = av_job_id
      iv_target_status = 'Ready'
      iv_timeout_sec = 180 ).
      
    cl_abap_unit_assert=>assert_true(
      act = lv_success
      msg = |Job { av_job_id } did not reach Ready status in time| ).
  ENDMETHOD.

  METHOD update_job_priority.
    " Create a new job specifically for this test
    av_job_id_for_priority = create_test_job( ).
    
    cl_abap_unit_assert=>assert_not_initial(
      act = av_job_id_for_priority
      msg = 'Job ID for priority test must be created' ).

    DATA(lv_new_priority) = 60.
    
    " Test updating job priority
    ao_s3c_actions->update_job_priority(
      iv_account_id = av_account_id
      iv_job_id = av_job_id_for_priority
      iv_priority = lv_new_priority ).

    " Verify priority was updated
    DATA(lo_result) = ao_s3c->describejob(
      iv_accountid = av_account_id
      iv_jobid = av_job_id_for_priority ).

    cl_abap_unit_assert=>assert_equals(
      exp = lv_new_priority
      act = lo_result->get_job( )->get_priority( )
      msg = 'Job priority should be updated to 60' ).
  ENDMETHOD.

  METHOD describe_job.
    " Use the job created in create_job test, or create new one if not available
    IF av_job_id IS INITIAL.
      av_job_id = create_test_job( ).
    ENDIF.
    
    cl_abap_unit_assert=>assert_not_initial(
      act = av_job_id
      msg = 'Job ID must be available for describe_job test' ).

    DATA lo_result TYPE REF TO /aws1/cl_s3cdescribejobresult.
    
    " Test describing a job
    ao_s3c_actions->describe_job(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = av_job_id
      IMPORTING
        oo_result = lo_result ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Describe job result should be bound' ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result->get_job( )
      msg = 'Job descriptor should be bound' ).

    cl_abap_unit_assert=>assert_equals(
      exp = av_job_id
      act = lo_result->get_job( )->get_jobid( )
      msg = 'Job ID should match' ).
      
    " Verify job has expected properties
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_job( )->get_status( )
      msg = 'Job status should not be initial' ).
      
    cl_abap_unit_assert=>assert_not_initial(
      act = lo_result->get_job( )->get_rolearn( )
      msg = 'Job role ARN should not be initial' ).
  ENDMETHOD.

  METHOD get_job_tagging.
    " Create a new job for this test
    av_job_id_for_tags = create_test_job( ).
    
    cl_abap_unit_assert=>assert_not_initial(
      act = av_job_id_for_tags
      msg = 'Job ID for tagging test must be created' ).

    DATA lo_result TYPE REF TO /aws1/cl_s3cgetjobtagresult.
    
    " Test getting job tags
    ao_s3c_actions->get_job_tagging(
      EXPORTING
        iv_account_id = av_account_id
        iv_job_id = av_job_id_for_tags
      IMPORTING
        oo_result = lo_result ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'Get job tagging result should be bound' ).
      
    " Job should have at least the TestTag we created
    DATA(lt_tags) = lo_result->get_tags( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_tags
      msg = 'Job should have tags from creation' ).
  ENDMETHOD.

  METHOD put_job_tagging.
    " Reuse the job from get_job_tagging test, or create new one
    IF av_job_id_for_tags IS INITIAL.
      av_job_id_for_tags = create_test_job( ).
    ENDIF.
    
    cl_abap_unit_assert=>assert_not_initial(
      act = av_job_id_for_tags
      msg = 'Job ID for tagging test must be available' ).

    " Create new tags to add
    DATA lt_tags TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
    APPEND NEW /aws1/cl_s3cs3tag( iv_key = 'Environment' iv_value = 'Development' ) TO lt_tags.
    APPEND NEW /aws1/cl_s3cs3tag( iv_key = 'Team' iv_value = 'DataProcessing' ) TO lt_tags.

    " Test putting job tags
    ao_s3c_actions->put_job_tagging(
      iv_account_id = av_account_id
      iv_job_id = av_job_id_for_tags
      it_tags = lt_tags ).

    " Verify tags were added
    DATA(lo_result) = ao_s3c->getjobtagging(
      iv_accountid = av_account_id
      iv_jobid = av_job_id_for_tags ).

    DATA(lt_result_tags) = lo_result->get_tags( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_result_tags
      msg = 'Tags should be present after put_job_tagging' ).
      
    " Verify at least one of our tags is present
    DATA lv_found_environment TYPE abap_bool.
    DATA lv_found_team TYPE abap_bool.
    LOOP AT lt_result_tags INTO DATA(lo_tag).
      IF lo_tag->get_key( ) = 'Environment' AND lo_tag->get_value( ) = 'Development'.
        lv_found_environment = abap_true.
      ENDIF.
      IF lo_tag->get_key( ) = 'Team' AND lo_tag->get_value( ) = 'DataProcessing'.
        lv_found_team = abap_true.
      ENDIF.
    ENDLOOP.
    
    cl_abap_unit_assert=>assert_true(
      act = lv_found_environment
      msg = 'Environment tag should be present' ).
    cl_abap_unit_assert=>assert_true(
      act = lv_found_team
      msg = 'Team tag should be present' ).
  ENDMETHOD.

  METHOD list_jobs.
    " Ensure at least one job exists
    IF av_job_id IS INITIAL.
      av_job_id = create_test_job( ).
    ENDIF.
    
    cl_abap_unit_assert=>assert_not_initial(
      act = av_job_id
      msg = 'At least one job must exist for list_jobs test' ).

    DATA lo_result TYPE REF TO /aws1/cl_s3clistjobsresult.
    
    " Create comprehensive list of job statuses to search
    DATA lt_statuses TYPE /aws1/cl_s3cjobstatuslist_w=>tt_jobstatuslist.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Active' ) TO lt_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Complete' ) TO lt_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Cancelled' ) TO lt_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Failed' ) TO lt_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Ready' ) TO lt_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Suspended' ) TO lt_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'New' ) TO lt_statuses.
    APPEND NEW /aws1/cl_s3cjobstatuslist_w( iv_value = 'Preparing' ) TO lt_statuses.

    " Test listing jobs
    ao_s3c_actions->list_jobs(
      EXPORTING
        iv_account_id = av_account_id
        it_statuses = lt_statuses
      IMPORTING
        oo_result = lo_result ).

    cl_abap_unit_assert=>assert_bound(
      act = lo_result
      msg = 'List jobs result should be bound' ).
      
    " Verify we got at least one job back (the one we created)
    DATA(lt_jobs) = lo_result->get_jobs( ).
    cl_abap_unit_assert=>assert_not_initial(
      act = lt_jobs
      msg = 'List jobs should return at least one job' ).
      
    " Verify our job is in the list
    DATA lv_found_job TYPE abap_bool.
    LOOP AT lt_jobs INTO DATA(lo_job).
      IF lo_job->get_jobid( ) = av_job_id.
        lv_found_job = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
    
    cl_abap_unit_assert=>assert_true(
      act = lv_found_job
      msg = |Created job { av_job_id } should be in the list| ).
  ENDMETHOD.

  METHOD delete_job_tagging.
    " Reuse the job from tagging tests, or create new one
    IF av_job_id_for_tags IS INITIAL.
      av_job_id_for_tags = create_test_job( ).
      
      " Add some tags first
      DATA lt_initial_tags TYPE /aws1/cl_s3cs3tag=>tt_s3tagset.
      APPEND NEW /aws1/cl_s3cs3tag( iv_key = 'DeleteTest' iv_value = 'Value1' ) TO lt_initial_tags.
      ao_s3c->putjobtagging(
        iv_accountid = av_account_id
        iv_jobid = av_job_id_for_tags
        it_tags = lt_initial_tags ).
    ENDIF.
    
    cl_abap_unit_assert=>assert_not_initial(
      act = av_job_id_for_tags
      msg = 'Job ID for delete tagging test must be available' ).

    " Test deleting job tags
    ao_s3c_actions->delete_job_tagging(
      iv_account_id = av_account_id
      iv_job_id = av_job_id_for_tags ).

    " Verify tags were deleted
    DATA(lo_result) = ao_s3c->getjobtagging(
      iv_accountid = av_account_id
      iv_jobid = av_job_id_for_tags ).

    DATA(lt_tags) = lo_result->get_tags( ).
    " After deletion, tags should be empty or only contain system tags
    " S3 Batch may retain some internal tags, so we just verify our custom tags are gone
    DATA lv_has_custom_tags TYPE abap_bool.
    LOOP AT lt_tags INTO DATA(lo_tag).
      DATA(lv_key) = lo_tag->get_key( ).
      IF lv_key = 'DeleteTest' OR lv_key = 'Environment' OR lv_key = 'Team'.
        lv_has_custom_tags = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
    
    cl_abap_unit_assert=>assert_false(
      act = lv_has_custom_tags
      msg = 'Custom tags should be deleted from job' ).
  ENDMETHOD.

  METHOD update_job_status.
    " Create a dedicated job for cancellation test
    av_job_id_for_cancel = create_test_job( ).
    
    cl_abap_unit_assert=>assert_not_initial(
      act = av_job_id_for_cancel
      msg = 'Job ID for status update test must be created' ).

    " Test updating job status to Cancelled
    ao_s3c_actions->update_job_status(
      iv_account_id = av_account_id
      iv_job_id = av_job_id_for_cancel
      iv_status = 'Cancelled' ).

    " Wait for cancellation to take effect
    WAIT UP TO 10 SECONDS.

    " Verify job was cancelled
    DATA(lo_result) = ao_s3c->describejob(
      iv_accountid = av_account_id
      iv_jobid = av_job_id_for_cancel ).

    DATA(lv_status) = lo_result->get_job( )->get_status( ).
    
    " Status should be Cancelled or Cancelling
    DATA lv_is_cancelled TYPE abap_bool.
    IF lv_status = 'Cancelled' OR lv_status = 'Cancelling'.
      lv_is_cancelled = abap_true.
    ENDIF.
    
    cl_abap_unit_assert=>assert_true(
      act = lv_is_cancelled
      msg = |Job status should be Cancelled or Cancelling, but is { lv_status }| ).
  ENDMETHOD.

ENDCLASS.
