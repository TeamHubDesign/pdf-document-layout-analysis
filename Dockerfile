FROM pytorch/pytorch:2.4.0-cuda11.8-cudnn9-runtime

RUN apt-get update
RUN apt-get install --fix-missing -y -q --no-install-recommends libgomp1 ffmpeg libsm6 libxext6 pdftohtml git ninja-build g++ qpdf pandoc

RUN mkdir -p /app/src
RUN mkdir -p /app/models

RUN addgroup --system python && adduser --system --group python
RUN chown -R python:python /app
USER python

ENV VIRTUAL_ENV=/app/.venv
RUN python -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY requirements.txt requirements.txt
RUN pip install --upgrade pip
RUN pip --default-timeout=1000 install -r requirements.txt

WORKDIR /app
RUN cd src; git clone https://github.com/facebookresearch/detectron2;
RUN cd src/detectron2; git checkout 70f454304e1a38378200459dd2dbca0f0f4a5ab4; python setup.py build develop

COPY ./start.sh ./start.sh
COPY ./src/. ./src

COPY ./models/. ./models
RUN python src/download_models.py

ENV PYTHONPATH "${PYTHONPATH}:/app"
ENV TRANSFORMERS_VERBOSITY=error
ENV TRANSFORMERS_NO_ADVISORY_WARNINGS=1


EXPOSE 5060
CMD ["gunicorn", "-k", "uvicorn.workers.UvicornWorker", "--chdir", "./src", "app:app", "--bind", "0.0.0.0:5060", "--timeout", "10000"]
