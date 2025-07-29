# Python 3.13 源码编译安装指南

本指南将引导您从源码编译安装 Python 3.13，并进行必要的配置。

## 1. 从源码编译安装

### 安装编译依赖

```bash
sudo apt update
sudo apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev
```

### 下载并编译 Python 3.13

```bash
# 下载Python 3.13源码
cd /tmp
wget https://www.python.org/ftp/python/3.13.0/Python-3.13.0.tgz
tar -xf Python-3.13.0.tgz
cd Python-3.13.0

# 配置和编译
./configure --enable-optimizations --prefix=/usr/local
make -j$(nproc)
sudo make altinstall

# 验证安装
/usr/local/bin/python3.13 --version
```

### 创建符号链接（可选但推荐）

```bash
# 创建方便使用的符号链接
sudo ln -sf /usr/local/bin/python3.13 /usr/local/bin/python3
sudo ln -sf /usr/local/bin/python3.13 /usr/local/bin/python

# 或者只是为python3.13创建一个更短的链接
sudo ln -sf /usr/local/bin/python3.13 /usr/bin/python3.13
```

## 2. 安装 pip（重要）

```bash
# 下载并安装pip
/usr/local/bin/python3.13 -m ensurepip --upgrade

# 或者手动安装pip
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
/usr/local/bin/python3.13 get-pip.py
rm get-pip.py
```

## 3. 更新 PATH 环境变量

```bash
# 添加到 ~/.bashrc
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 4. 安装常用包

```bash
# 升级pip
/usr/local/bin/python3.13 -m pip install --upgrade pip

# 安装常用包
/usr/local/bin/python3.13 -m pip install setuptools wheel virtualenv
```

## 验证安装

### 基本验证

```bash
/usr/local/bin/python3.13 --version
/usr/local/bin/python3.13 -c "import sys; print(sys.version_info)"
/usr/local/bin/python3.13 -m pip --version
```

### 验证安装是否正常

```bash
python3.13 --version
python3 --version
python --version
python3.13 -m pip --version
```

### 更新PATH并测试

```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 测试是否可以直接使用
which python3.13
which python3
```

## 3. 关于 root 用户警告的处理

由于你现在是 root 用户，有几个选择：

### 选项A：继续使用root但抑制警告

```bash
python3.13 -m pip install --root-user-action=ignore package_name
```

### 选项B：创建虚拟环境（推荐）

```bash
# 即使是root用户也可以创建虚拟环境
python3.13 -m venv /opt/myenv
source /opt/myenv/bin/activate
# 现在在虚拟环境中安装包就不会有警告了
```

### 选项C：创建普通用户来使用Python

```bash
# 创建一个普通用户
adduser pythonuser
su - pythonuser
# 然后使用python3.13
```

## 4. 测试 Python 3.13 的新特性

```bash
python3.13 -c "
import sys
print(f'Python version: {sys.version}')
print('Testing new Python 3.13 features...')
"
```

## 5. 清理安装文件

```bash
cd ~
rm -rf /tmp/Python-3.13.0*
```

## 安装常用包

```bash
python -m pip install --root-user-action=ignore requests numpy pandas

# 或者创建虚拟环境来避免root警告
python -m venv ~/myproject
source ~/myproject/bin/activate
```

## 测试新特性

```bash
python -c "
print('🎉 Python 3.13 ready!')
import sys
print(f'Version: {sys.version_info}')
print('New features include improved error messages, better performance, and more!')
"
```

## 从 requirements.txt 安装包

```bash
/usr/local/bin/python3.13 -m pip install -r requirements.txt --root-user-action=ignore
```

---

现在你可以开始使用 Python 3.13 了！🐍✨
