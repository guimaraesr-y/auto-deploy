from celery import shared_task
from .models import PaymentOrder

@shared_task
def process_payment(payment_order_id):
    try:
        payment_order = PaymentOrder.objects.get(id=payment_order_id)
        payment_order.is_paid = True
        payment_order.save()
        return f"Payment order {payment_order_id} processed successfully."
    except PaymentOrder.DoesNotExist:
        return f"Payment order {payment_order_id} not found."
