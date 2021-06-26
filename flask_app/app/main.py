from flask import Flask
from flask_restplus import Api

app = Flask(__name__)
api = Api(title='Ansible-Terraform Test API', prefix='/api/v1',  doc='/api/v1/swagger-ui.html')
api.init_app(app)


@app.route('/')
def hello_cloud():
    return "Welcome to Tennison's attempt at Ansible and Terraform"


if __name__ == "__main__":
   app.run(host='0.0.0.0', port=80)
