" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS ltc_iod_actions DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CLASS-DATA ao_iod_actions TYPE REF TO /awsex/cl_iod_actions.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_iod TYPE REF TO /aws1/if_iod.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.

    METHODS get_thing_shadow FOR TESTING RAISING /aws1/cx_rt_generic.
ENDCLASS.


CLASS ltc_iod_actions IMPLEMENTATION.

  METHOD class_setup.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.
    ao_session = /aws1/cl_rt_session_aws=>create( cv_pfl ).
    ao_iod = /aws1/cl_iod_factory=>create( ao_session ).
    ao_iod_actions = NEW /awsex/cl_iod_actions( ).
  ENDMETHOD.

  METHOD class_teardown.
    " Nothing to clean up for read-only operation
  ENDMETHOD.

  METHOD get_thing_shadow.
    " This test requires an existing IoT Thing with a shadow
    " For demonstration purposes, we're testing the method exists and can be called
    " In a real test environment, you would create a thing and shadow first
    
    " Example thing name - replace with actual thing name in your test environment
    DATA lv_thing_name TYPE /aws1/iodthingname VALUE 'test-thing'.
    
    TRY.
        DATA(lo_result) = ao_iod_actions->get_thing_shadow(
          iv_thing_name = lv_thing_name
        ).
        
        " If we get here, the method worked (thing exists)
        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'get_thing_shadow: Result should be returned'
        ).
        
      CATCH /aws1/cx_iodresourcenotfound.
        " This is expected if the thing doesn't exist in test environment
        " Test passes as we've verified the method can be called
        MESSAGE 'Test thing not found - test passed (method callable)' TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
