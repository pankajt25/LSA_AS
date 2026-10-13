# Authentication service logic
def authenticate(token):
    return token.startswith("Bearer valid_")
