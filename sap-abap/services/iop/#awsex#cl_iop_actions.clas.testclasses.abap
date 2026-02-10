" Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
" SPDX-License-Identifier: Apache-2.0

CLASS ltc_iop_actions DEFINITION DEFERRED.
CLASS /awsex/cl_iop_actions DEFINITION LOCAL FRIENDS ltc_iop_actions.

CLASS ltc_iop_actions DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-DATA ao_iop_actions TYPE REF TO /awsex/cl_iop_actions.
    CLASS-METHODS class_setup RAISING /aws1/cx_rt_generic.
ENDCLASS.

CLASS ltc_iop_actions IMPLEMENTATION.
  METHOD class_setup.
    ao_iop_actions = NEW /awsex/cl_iop_actions( ).
  ENDMETHOD.
ENDCLASS.
