" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS /awsex/cl_iop_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS get_thing_shadow
      IMPORTING
        !iv_thing_name TYPE /aws1/iopthingname
      EXPORTING
        !oo_result TYPE REF TO /aws1/cl_iopgetthingshadowrsp
      RAISING
        /aws1/cx_rt_generic.

ENDCLASS.

CLASS /awsex/cl_iop_actions IMPLEMENTATION.
  METHOD get_thing_shadow.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iop) = /aws1/cl_iop_factory=>create( lo_session ).

    " snippet-start:[iop.abapv1.get_thing_shadow]
    TRY.
        oo_result = lo_iop->getthingshadow(
          iv_thingname = iv_thing_name
        ).
        MESSAGE 'Retrieved thing shadow successfully.' TYPE 'I'.
      CATCH /aws1/cx_iopresourcenotfoundex.
        MESSAGE 'Thing shadow not found.' TYPE 'E'.
      CATCH /aws1/cx_iopinternalfailureex.
        MESSAGE 'Internal service error occurred.' TYPE 'E'.
      CATCH /aws1/cx_iopinvalidrequestex.
        MESSAGE 'Invalid request parameters.' TYPE 'E'.
      CATCH /aws1/cx_iopthrottlingex.
        MESSAGE 'Request throttled - rate limit exceeded.' TYPE 'E'.
      CATCH /aws1/cx_iopunauthorizedex.
        MESSAGE 'Unauthorized access.' TYPE 'E'.
      CATCH /aws1/cx_iopserviceunavailex.
        MESSAGE 'Service temporarily unavailable.' TYPE 'E'.
    ENDTRY.
    " snippet-end:[iop.abapv1.get_thing_shadow]
  ENDMETHOD.

ENDCLASS.
