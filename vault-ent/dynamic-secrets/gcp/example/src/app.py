import datetime
import googleproject
import os

from flask import Flask

app = Flask(__name__)

proj = googleproject.GoogleProject()

PROJECT_ID = os.environ.get('PROJECT_ID')

@app.route('/')
def hello():
    return 'Hello, World!'

@app.route('/health')
def health():
    return 'OK'

@app.route('/project')
def project():
    text = None
    if PROJECT_ID:
        try:
            text = "<PRE>%s\n%s\n</PRE>" % (str(proj.get(PROJECT_ID)), datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        except Exception as e:
            text = "<PRE>%s\n%s\n</PRE>" % (str(e), datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    else:
        text = "No Project ID found"

    return text
