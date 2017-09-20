from centos:7
ENV VER=10.2
RUN yum install -y m4 git && \
  git clone http://github.com/AndriiNikitin/mariadb-environs && \
  cd mariadb-environs && \
  ./replant.sh m0-system && \
  m0-system/install.sh $VER

RUN useradd a && \
  echo "a:1"|chpasswd


RUN chmod +r /etc/shadow && \
  mkdir /faillock && \
  chown mysql:mysql /faillock && \
  echo "auth     requisite      pam_faillock.so preauth silent even_deny_root unlock_time=60 dir=/faillock" > /etc/pam.d/mtest && \
  echo "auth     sufficient     pam_unix.so" >> /etc/pam.d/mtest && \
  echo "auth     [default=die]  pam_faillock.so authfail even_deny_root unlock_time=60 dir=/faillock" >> /etc/pam.d/mtest && \
  echo "auth     required       pam_deny.so" >> /etc/pam.d/mtest && \
  echo "account  required       pam_faillock.so dir=/faillock" >> /etc/pam.d/mtest && \
  echo "account  required       pam_unix.so" >> /etc/pam.d/mtest

ENTRYPOINT bash
