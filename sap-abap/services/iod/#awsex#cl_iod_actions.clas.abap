" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS /awsex/cl_iod_actions DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS get_thing_shadow
      IMPORTING iv_thing_name TYPE /aws1/iodthingname
                iv_shadow_name TYPE /aws1/iodshadowname OPTIONAL
      RETURNING VALUE(oo_result) TYPE REF TO /aws1/cl_iodgetthingshadowrsp
      RAISING /aws1/cx_rt_generic.
ENDCLASS.

CLASS /awsex/cl_iod_actions IMPLEMENTATION.
  METHOD get_thing_shadow.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iod) = /aws1/cl_iod_factory=>create( lo_session ).
    " snippet-start:[iod.abapv1.get_thing_shadow]
    TRY.
        oo_result = lo_iod->getthingshadow( iv_thingname = iv_thing_name iv_shadowname = iv_shadow_name ).
        MESSAGE 'Retrieved thing shadow successfully.' TYPE 'I'.
      CATCH /aws1/cx_iodresourcenotfound.
        MESSAGE 'Thing or shadow not found.' TYPE 'E'.
      CATCH /aws1/cx_iodinternalfailureex.
        MESSAGE 'Internal service error occurred.' TYPE 'E'.
      CATCH /aws1/cx_iodinvalidrequestex.
        MESSAGE 'Invalid request parameters.' TYPE 'E'.
      CATCH /aws1/cx_iodthrottlingexception.
        MESSAGE 'Request throttled - rate limit exceeded.' TYPE 'E'.
      CATCH /aws1/cx_iodunauthorizedex.
        MESSAGE 'Unauthorized access.' TYPE 'E'.
      CATCH /aws1/cx_iodserviceunavailex.
        MESSAGE 'Service temporarily unavailable.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[iod.abapv1.get_thing_shadow]
  ENDMETHOD.
ENDCLASS.
