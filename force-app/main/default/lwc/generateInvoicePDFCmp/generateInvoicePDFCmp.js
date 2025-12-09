/**
 * Created on 03/07/2024.
 */

import { api, LightningElement } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from "lightning/actions";
import generatePDF from "@salesforce/apex/GenerateInvoicePDFCtrl.generatePDF"

export default class GenerateInvoicePdfCmp extends LightningElement {
  @api recordId;

  disabled = false;

  handleCancel(evt) {
    this.dispatchEvent(new CloseActionScreenEvent());
  }
  handleGenerate(evt) {
    this.disabled = true;
    generatePDF({ invoiceId: this.recordId })
      .then(data => {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "The PDF will be generated in a few seconds.",
            variant: "success",
          }),
        );
      })
      .catch(error => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: error?.body?.message || error,
            variant: "error",
          }),
        );
      });
  }
}