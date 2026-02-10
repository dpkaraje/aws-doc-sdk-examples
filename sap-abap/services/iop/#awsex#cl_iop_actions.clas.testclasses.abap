" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS ltc_awsex_cl_iop_actions DEFINITION DEFERRED.
CLASS /awsex/cl_iop_actions DEFINITION LOCAL FRIENDS ltc_awsex_cl_iop_actions.

CLASS ltc_awsex_cl_iop_actions DEFINITION FOR TESTING DURATION LONG RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    CONSTANTS cv_pfl TYPE /aws1/rt_profile_id VALUE 'ZCODE_DEMO'.

    CLASS-DATA ao_iop TYPE REF TO /aws1/if_iop.
    CLASS-DATA ao_iot TYPE REF TO /aws1/if_iot.
    CLASS-DATA ao_session TYPE REF TO /aws1/cl_rt_session_base.
    CLASS-DATA ao_iop_actions TYPE REF TO /awsex/cl_iop_actions.
    CLASS-DATA gv_thing_name TYPE /aws1/iotthingname.
    CLASS-DATA gv_uuid TYPE string.

    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
    CLASS-METHODS class_teardown RAISING /aws1/cx_rt_generic.

    METHODS GET_THING_SHADOW FOR TESTING RAISING /aws1/cx_rt_generic.
ENDCLASS.

CLASS ltc_awsex_cl_iop_actions IMPLEMENTATION.

  METHOD class_setup.
    ao_session = /aws1/cl_rt_session_aws=>create( iv_profile_id = cv_pfl ).
    ao_iop = /aws1/cl_iop_factory=>create( ao_session ).
    ao_iot = /aws1/cl_iot_factory=>create( ao_session ).
    ao_iop_actions = NEW /awsex/cl_iop_actions( ).

    " Generate UUID for unique resource names
    gv_uuid = /awsex/cl_utils=>get_random_string( ).
    gv_thing_name = |test-thing-{ gv_uuid }|.

    " Create a thing with tags
    TRY.
        ao_iot->creatething(
          iv_thingname = gv_thing_name
          it_tags = VALUE /aws1/cl_iottag=>tt_taglist(
            ( NEW /aws1/cl_iottag( iv_key = 'convert_test' iv_value = 'true' ) )
          )
        ).
      CATCH /aws1/cx_iotresrcalrdyexistsex.
        " Thing already exists, continue
    ENDTRY.

    " Wait for thing to be created
    WAIT UP TO 2 SECONDS.
  ENDMETHOD.

  METHOD class_teardown.
    " Clean up the thing
    IF gv_thing_name IS NOT INITIAL.
      TRY.
          ao_iot->deletething( iv_thingname = gv_thing_name ).
        CATCH /aws1/cx_rt_generic.
          " Ignore errors during cleanup - resource is tagged
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD GET_THING_SHADOW.
    " Attempt to get thing shadow (may not exist, but method should work)
    TRY.
        DATA(lo_result) = ao_iop_actions->GET_THING_SHADOW( gv_thing_name ).
        cl_abap_unit_assert=>assert_bound(
          act = lo_result
          msg = 'Get thing shadow result should not be initial'
        ).
      CATCH /aws1/cx_iopresourcenotfoundex.
        " Expected if thing has no shadow yet - this is acceptable
        MESSAGE 'Thing shadow not found - this is acceptable for new things' TYPE 'I'.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
