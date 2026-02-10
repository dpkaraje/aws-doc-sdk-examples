" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS ltc_iod_actions DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS dummy_test FOR TESTING.
ENDCLASS.


CLASS ltc_iod_actions IMPLEMENTATION.

  METHOD dummy_test.
    " Placeholder test for empty stub class
    cl_abap_unit_assert=>assert_true( act = abap_true ).
  ENDMETHOD.

ENDCLASS.

