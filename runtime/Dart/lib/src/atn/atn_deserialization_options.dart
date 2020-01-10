/*
 * Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

class ATNDeserializationOptions {
  static final ATNDeserializationOptions defaultOptions =
      ATNDeserializationOptions()..makeReadOnly();

  bool readOnly;
  bool verifyATN;
  bool generateRuleBypassTransitions;

  ATNDeserializationOptions([ATNDeserializationOptions options]) {
    if (options == null) {
      this.verifyATN = true;
      this.generateRuleBypassTransitions = false;
    } else {
      this.verifyATN = options.verifyATN;
      this.generateRuleBypassTransitions =
          options.generateRuleBypassTransitions;
    }
  }

  static ATNDeserializationOptions getDefaultOptions() {
    return defaultOptions;
  }

  bool isReadOnly() {
    return readOnly;
  }

  void makeReadOnly() {
    readOnly = true;
  }

  bool isVerifyATN() {
    return verifyATN;
  }

  void setVerifyATN(bool verifyATN) {
    throwIfReadOnly();
    this.verifyATN = verifyATN;
  }

  bool isGenerateRuleBypassTransitions() {
    return generateRuleBypassTransitions;
  }

  void setGenerateRuleBypassTransitions(bool generateRuleBypassTransitions) {
    throwIfReadOnly();
    this.generateRuleBypassTransitions = generateRuleBypassTransitions;
  }

  void throwIfReadOnly() {
    if (isReadOnly()) {
      throw new StateError("The object is read only.");
    }
  }
}
