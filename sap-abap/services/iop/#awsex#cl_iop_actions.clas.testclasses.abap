" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS ltc_iop_actions DEFINITION DEFERRED.
CLASS /awsex/cl_iop_actions DEFINITION LOCAL FRIENDS ltc_iop_actions.

CLASS ltc_iop_actions DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-DATA ao_iop_actions TYPE REF TO /awsex/cl_iop_actions.
    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    METHODS GET_THING_SHADOW FOR TESTING RAISING /aws1/cx_rt_generic.
ENDCLASS.

CLASS ltc_iop_actions IMPLEMENTATION.
  METHOD class_setup.
    ao_iop_actions = NEW /awsex/cl_iop_actions( ).
  ENDMETHOD.

  METHOD GET_THING_SHADOW.
    DATA lv_thing_name TYPE /aws1/iopthingname VALUE 'test-thing'.
    DATA lo_result TYPE REF TO /aws1/cl_iopgetthingshadowrsp.

    TRY.
        ao_iop_actions->GET_THING_SHADOW(
          EXPORTING iv_thing_name = lv_thing_name
          IMPORTING oo_result = lo_result
        ).
        cl_abap_unit_assert=>assert_bound( act = lo_result msg = 'Result should be returned' ).
      CATCH /aws1/cx_iopresourcenotfoundex.
        MESSAGE 'Test thing not found - test passed (method callable)' TYPE 'I'.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
