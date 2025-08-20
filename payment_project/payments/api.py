from ninja import NinjaAPI
from .models import User, PaymentOrder
from .schemas import UserSchema, UserSchemaIn, PaymentOrderSchema, PaymentOrderSchemaIn
from .tasks import process_payment
from typing import List

api = NinjaAPI()

@api.post("/users", response=UserSchema)
def create_user(request, payload: UserSchemaIn):
    user = User.objects.create(**payload.dict())
    return user

@api.get("/users", response=List[UserSchema])
def list_users(request):
    return User.objects.all()

@api.get("/users/{user_id}", response=UserSchema)
def get_user(request, user_id: int):
    return User.objects.get(id=user_id)

@api.post("/payment-orders", response=PaymentOrderSchema)
def create_payment_order(request, payload: PaymentOrderSchemaIn):
    payment_order = PaymentOrder.objects.create(**payload.dict())
    process_payment.delay(payment_order.id)
    return payment_order

@api.get("/payment-orders", response=List[PaymentOrderSchema])
def list_payment_orders(request):
    return PaymentOrder.objects.all()

@api.get("/payment-orders/{payment_order_id}", response=PaymentOrderSchema)
def get_payment_order(request, payment_order_id: int):
    return PaymentOrder.objects.get(id=payment_order_id)
