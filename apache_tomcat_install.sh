#!/bin/bash

LOGFILE="/usr/local/src/apache_tomcat_install.log"
SRC_DIR="/usr/local/src"
APACHE_INSTALL_DIR="/usr/local/apache"
TOMCAT_INSTALL_DIR="/usr/local/tomcat"

echo "===========================" | tee -a $LOGFILE
echo "Apache & Tomcat 설치 스크립트" | tee -a $LOGFILE
echo "===========================" | tee -a $LOGFILE

# OS 확인
OS_NAME=$(grep '^NAME' /etc/os-release | awk -F= '{print $2}' | tr -d '"')
echo "현재 OS: $OS_NAME" | tee -a $LOGFILE
if [[ $OS_NAME != "Rocky Linux" && $OS_NAME != "CentOS Linux" && $OS_NAME != "Ubuntu" ]]; then
  echo "이 스크립트는 Rocky Linux, CentOS, Ubuntu만 지원합니다." | tee -a $LOGFILE
  exit 1
fi

# Apache 설치 여부 확인
read -p "Apache를 설치하시겠습니까? (Y/N): " INSTALL_APACHE
if [[ "$INSTALL_APACHE" =~ ^[Yy]$ ]]; then
  echo "Apache 설치를 시작합니다..." | tee -a $LOGFILE
  # 필수 패키지 설치
  if [[ $OS_NAME == "Ubuntu" ]]; then
    sudo apt-get update
    sudo apt-get install -y build-essential libpcre3 libpcre3-dev zlib1g-dev libssl-dev | tee -a $LOGFILE
  elif [[ $OS_NAME == "CentOS Linux" || $OS_NAME == "Rocky Linux" ]]; then
    if grep -q -i "release 7" /etc/redhat-release; then
      # CentOS 7은 yum 사용
      sudo yum install -y gcc gcc-c++ make pcre pcre-devel zlib-devel openssl-devel | tee -a $LOGFILE
    else
      # CentOS 8 이상이나 Rocky Linux는 dnf 사용
      sudo dnf install -y gcc gcc-c++ make pcre pcre-devel zlib-devel openssl-devel | tee -a $LOGFILE
    fi
  fi

  # 최신 Apache, APR, APR-Util 버전 가져오기
  cd $SRC_DIR
  APACHE_LATEST_URL=$(curl -s https://downloads.apache.org/httpd/ | grep -oP 'httpd-\d+\.\d+\.\d+\.tar\.gz' | sort -Vr | head -n 1)
  APR_LATEST_URL=$(curl -s https://downloads.apache.org/apr/ | grep -oP 'apr-\d+\.\d+\.\d+\.tar\.gz' | sort -Vr | head -n 1)
  APR_UTIL_LATEST_URL=$(curl -s https://downloads.apache.org/apr/ | grep -oP 'apr-util-\d+\.\d+\.\d+\.tar\.gz' | sort -Vr | head -n 1)

  # 파일 다운로드
  wget "https://downloads.apache.org/httpd/$APACHE_LATEST_URL"
  wget "https://downloads.apache.org/apr/$APR_LATEST_URL"
  wget "https://downloads.apache.org/apr/$APR_UTIL_LATEST_URL"

  # 파일 추출 및 이동
  tar -zxvf $APR_LATEST_URL
  tar -zxvf $APR_UTIL_LATEST_URL
  tar -zxvf $APACHE_LATEST_URL
  APACHE_DIR=$(basename $APACHE_LATEST_URL .tar.gz)
  APR_DIR=$(basename $APR_LATEST_URL .tar.gz)
  APR_UTIL_DIR=$(basename $APR_UTIL_LATEST_URL .tar.gz)

  mv $APR_DIR $APACHE_DIR/srclib/apr
  mv $APR_UTIL_DIR $APACHE_DIR/srclib/apr-util

  # Apache 다운로드 및 설치
  cd $APACHE_DIR
  ./configure --prefix=$APACHE_INSTALL_DIR --enable-so --enable-ssl --enable-rewrite --with-included-apr | tee -a $LOGFILE
  if make | tee -a $LOGFILE && make install | tee -a $LOGFILE; then
    echo "Apache 설치 완료" | tee -a $LOGFILE
  else
    echo "Apache 설치 실패. 로그를 확인하세요." | tee -a $LOGFILE
    exit 1
  fi
else
  echo "Apache 설치를 건너뜁니다." | tee -a $LOGFILE
fi

# Tomcat 설치 여부 확인
read -p "Tomcat을 설치하시겠습니까? (Y/N): " INSTALL_TOMCAT
if [[ "$INSTALL_TOMCAT" =~ ^[Yy]$ ]]; then
  echo "설치할 Tomcat 버전을 선택하세요:"
  echo "1) 8.0"
  echo "2) 8.5"
  echo "3) 9.0"
  echo "4) 10.0"
  echo "5) 10.1"
  echo "6) 11.0"
  read -p "숫자를 입력하세요 (1-6): " TOMCAT_SELECTION
  case $TOMCAT_SELECTION in
    1) TOMCAT_VERSION="8.0"; TOMCAT_MAJOR="8" ;;
    2) TOMCAT_VERSION="8.5"; TOMCAT_MAJOR="8" ;;
    3) TOMCAT_VERSION="9.0"; TOMCAT_MAJOR="9" ;;
    4) TOMCAT_VERSION="10.0"; TOMCAT_MAJOR="10" ;;
    5) TOMCAT_VERSION="10.1"; TOMCAT_MAJOR="10" ;;
    6) TOMCAT_VERSION="11.0"; TOMCAT_MAJOR="11" ;;
    *) echo "지원되지 않는 선택입니다." | tee -a $LOGFILE; exit 1 ;;
  esac
  TOMCAT_DOWNLOAD_URL="https://dlcdn.apache.org/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}.0/bin/apache-tomcat-${TOMCAT_VERSION}.0.tar.gz"
  cd $SRC_DIR
  wget $TOMCAT_DOWNLOAD_URL -O tomcat.tar.gz
  tar -zxvf tomcat.tar.gz
  mv apache-tomcat-${TOMCAT_VERSION}.0 $TOMCAT_INSTALL_DIR
  if [[ $? -eq 0 ]]; then
    echo "Tomcat ${TOMCAT_VERSION} 설치 완료" | tee -a $LOGFILE
  else
    echo "Tomcat 설치 실패. 로그를 확인하세요." | tee -a $LOGFILE
    exit 1
  fi

  # Java 설치 여부 확인
  read -p "Java를 설치하시겠습니까? (Y/N): " INSTALL_JAVA
  if [[ "$INSTALL_JAVA" =~ ^[Yy]$ ]]; then
    if [[ $TOMCAT_VERSION =~ ^(8\.0|8\.5|9\.0|10\.0)$ ]]; then
      sudo yum install -y java-1.8.0-openjdk-devel | tee -a $LOGFILE
    elif [[ $TOMCAT_VERSION == "10.1" ]]; then
      sudo yum install -y java-11-openjdk-devel | tee -a $LOGFILE
    elif [[ $TOMCAT_VERSION == "11.0" ]]; then
      sudo yum install -y java-17-openjdk-devel | tee -a $LOGFILE
    fi
    if [[ $? -eq 0 ]]; then
      echo "Java 설치 완료" | tee -a $LOGFILE
    else
      echo "Java 설치 실패. 로그를 확인하세요." | tee -a $LOGFILE
    fi
  fi
else
  echo "Tomcat 설치를 건너뜁니다." | tee -a $LOGFILE
fi

echo "설치 스크립트 완료." | tee -a $LOGFILE
