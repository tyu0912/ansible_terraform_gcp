FROM tiangolo/uwsgi-nginx-flask:python3.7

RUN mkdir /src
COPY requirements.txt /src

COPY  ./app /src

WORKDIR /src
RUN pip install -r requirements.txt

EXPOSE 80