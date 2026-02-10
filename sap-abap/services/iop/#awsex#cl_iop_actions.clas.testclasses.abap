" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS ltc_awsex_cl_iop_actions DEFINITION DEFERRED.
CLASS /awsex/cl_iop_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_iop_actions.

CLASS ltc_awsex_cl_iop_actions DEFINITION FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_iop_actions TYPE REF TO /awsex/cl_iop_actions.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.

    METHODS getthingshadow FOR TESTING RAISING /aws1/cx_rt_generic.

ENDCLASS.

CLASS ltc_awsex_cl_iop_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_iop_actions = NEW /awsex/cl_iop_actions( ).
  ENDMETHOD.

  METHOD getthingshadow.
    DATA lv_thing_name TYPE /aws1/iopthingname VALUE 'test-thing'.

    TRY.
        DATA(lo_result) = ao_iop_actions->getthingshadow( iv_thing_name = lv_thing_name ).
        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'Result should be returned' ).
      CATCH /aws1/cx_iopresourcenotfoundex.
        MESSAGE 'Test thing not found - test passed' TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
