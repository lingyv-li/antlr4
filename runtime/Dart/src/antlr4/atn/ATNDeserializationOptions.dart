/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

class ATNDeserializationOptions {
  bool readOnly;
  var verifyATN;
  var generateRuleBypassTransitions;
  ATNDeserializationOptions({copyFrom = null}) {
    this.readOnly = false;
    this.verifyATN = copyFrom == null ? true : copyFrom.verifyATN;
    this.generateRuleBypassTransitions =
        copyFrom == null ? false : copyFrom.generateRuleBypassTransitions;
  }
  static final defaultOptions = () {
    final opt = ATNDeserializationOptions(copyFrom: null);
    opt.readOnly = true;
    return opt;
  }();

//    def __setattr__(self, key, value):
//        if key!="readOnly" and self.readOnly:
//            raise Exception("The object is read only.")
//        super(type(self), self).__setattr__(key,value)
}
