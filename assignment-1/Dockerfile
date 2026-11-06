# CLO835 - Assignment 1 - the web tier.
#
# Ubuntu 26.04 LTS ships Python 3.14. It also protects the system Python
# (PEP 668), so "pip install" into the system fails. A virtual environment is
# the correct answer, and it matches the Week 02 and Week 03 labs.
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y \
 && apt-get install -y --no-install-recommends \
      python3 python3-venv mysql-client ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# requirements.txt is copied first, so Docker reuses this layer when only
# the application code changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080
CMD ["python3", "app.py"]
