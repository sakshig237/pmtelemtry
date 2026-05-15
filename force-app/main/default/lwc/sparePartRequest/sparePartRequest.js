import { LightningElement, api, wire } from 'lwc';
import requestSparePart from '@salesforce/apex/sparePartsRequestController.requestSparePart';
import getRecommendedProducts from '@salesforce/apex/sparePartsRequestController.getRecommendedProducts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SparePartRequest extends LightningElement {

    @api recordId;

    productId;
    quantity = 1;
    requestId;

    productOptions = []; 

    quantity = 1;

// Handle manual input
handleQuantityChange(event) {
    this.quantity = parseInt(event.target.value, 10);

    if (!this.quantity || this.quantity < 1) {
        this.quantity = 1;
    }
}

// Increase
increaseQuantity() {
    this.quantity = (this.quantity || 1) + 1;
}

// Decrease
decreaseQuantity() {
    if (this.quantity > 1) {
        this.quantity = this.quantity - 1;
    }
}

get isMinQuantity() {
    return this.quantity <= 1;
}


    @wire(getRecommendedProducts, { workOrderId: '$recordId' })
    wiredProducts({ error, data }) {
        if (data) {
            this.productOptions = data.map(p => ({
                label: p.Name,
                value: p.Id
            }));
        } else if (error) {
            console.error(error);
            this.showToast('Error', 'Failed to load products', 'error');
        }
    }

    handleProductChange(event) {
        this.productId = event.target.value;
    }

    handleQuantityChange(event) {
        this.quantity = event.target.value;
    }

    handleRequest() {
        if (!this.productId || !this.quantity) {
            this.showToast('Error', 'Please enter all fields', 'error');
            return;
        }

        requestSparePart({
            workOrderId: this.recordId,
            productId: this.productId,
            quantity: parseInt(this.quantity, 10)
        })
        .then(result => {
            this.requestId = result;
            this.showToast('Success', 'Spare part requested successfully', 'success');
        })
        .catch(error => {
            const message = error?.body?.message || error.message || 'Unknown error';
            this.showToast('Error', message, 'error');
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}
