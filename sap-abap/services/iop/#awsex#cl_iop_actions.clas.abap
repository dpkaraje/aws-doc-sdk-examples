" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS /awsex/cl_iop_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS GET_THING_SHADOW
      IMPORTING
        !IV_THING_NAME        TYPE /aws1/iopthingname
      RETURNING
        VALUE(OO_RESULT)      TYPE REF TO /aws1/cl_iopgetthingshadowrsp
      RAISING
        /aws1/cx_rt_generic .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS /AWSEX/CL_IOP_ACTIONS IMPLEMENTATION.


  METHOD GET_THING_SHADOW.

    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    DATA(lo_session) = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    DATA(lo_iop) = /aws1/cl_iop_factory=>create( lo_session ).

    " snippet-start:[iop.abapv1.get_thing_shadow]
    TRY.
        OO_RESULT = lo_iop->getthingshadow( iv_thingname = IV_THING_NAME ).
        MESSAGE 'Retrieved thing shadow successfully.' TYPE 'I'.
      CATCH /aws1/cx_iopresourcenotfoundex.
        MESSAGE 'Thing shadow not found.' TYPE 'I'.
      CATCH /aws1/cx_iopinternalfailureex.
        MESSAGE 'Internal service error occurred.' TYPE 'I'.
      CATCH /aws1/cx_iopinvalidrequestex.
        MESSAGE 'Invalid request parameters.' TYPE 'I'.
      CATCH /aws1/cx_iopthrottlingex.
        MESSAGE 'Request throttled - rate limit exceeded.' TYPE 'I'.
      CATCH /aws1/cx_iopunauthorizedex.
        MESSAGE 'Unauthorized access.' TYPE 'I'.
      CATCH /aws1/cx_iopserviceunavailex.
        MESSAGE 'Service temporarily unavailable.' TYPE 'I'.
    ENDTRY.
    " snippet-end:[iop.abapv1.get_thing_shadow]

  ENDMETHOD.

ENDCLASS.
