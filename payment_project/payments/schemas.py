from ninja import Schema
from datetime import datetime

class UserSchema(Schema):
    id: int
    first_name: str
    last_name: str
    email: str
    created_at: datetime

class UserSchemaIn(Schema):
    first_name: str
    last_name: str
    email: str

class PaymentOrderSchema(Schema):
    id: int
    user_id: int
    amount: float
    is_paid: bool
    created_at: datetime
    updated_at: datetime

class PaymentOrderSchemaIn(Schema):
    user_id: int
    amount: float
