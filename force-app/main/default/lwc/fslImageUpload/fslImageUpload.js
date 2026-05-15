import { LightningElement, api, track } from 'lwc';
import uploadFile from '@salesforce/apex/FileUploadController.uploadFile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class FslImageUpload extends LightningElement {

    @api recordId;

    @track previewUrl;
    @track isLoading = false;

    canvas;
    ctx;
    isDrawing = false;

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        const reader = new FileReader();

        reader.onload = () => {
            this.previewUrl = reader.result;

            setTimeout(() => {
                this.initializeCanvas();
            }, 200);
        };

        reader.readAsDataURL(file);
    }

    initializeCanvas() {
        this.canvas = this.template.querySelector('canvas');
        this.ctx = this.canvas.getContext('2d');

        const img = new Image();
        img.src = this.previewUrl;

        img.onload = () => {
            this.ctx.drawImage(img, 0, 0, this.canvas.width, this.canvas.height);
        };
    }

    startDrawing(event) {
        event.preventDefault();
        this.isDrawing = true;
    }

    draw(event) {
        if (!this.isDrawing) return;

        event.preventDefault();

        const rect = this.canvas.getBoundingClientRect();

        const x = (event.touches ? event.touches[0].clientX : event.clientX) - rect.left;
        const y = (event.touches ? event.touches[0].clientY : event.clientY) - rect.top;

        this.ctx.lineWidth = 3;
        this.ctx.lineCap = 'round';
        this.ctx.strokeStyle = 'red';

        this.ctx.lineTo(x, y);
        this.ctx.stroke();
        this.ctx.beginPath();
        this.ctx.moveTo(x, y);
    }

    stopDrawing() {
        this.isDrawing = false;
        this.ctx.beginPath();
    }

    clearCanvas() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        this.initializeCanvas();
    }

    handleUpload() {
        this.isLoading = true;

        const dataUrl = this.canvas.toDataURL('image/png');
        const base64 = dataUrl.split(',')[1];

        uploadFile({
            fileName: 'Annotated_Image.png',
            base64Data: base64,
            recordId: this.recordId
        })
        .then(() => {
            this.showToast('Success', 'Annotated image uploaded', 'success');
            this.previewUrl = null;
        })
        .catch(err => {
            this.showToast('Error', err.body?.message, 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
