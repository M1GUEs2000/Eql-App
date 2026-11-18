"""Corre la app en http://localhost:8080 con hot reload automatico.

Uso (desde cualquier carpeta):  python dev_8080.py

- Cada vez que guardas un .dart dentro de lib/ manda 'r' (hot reload) a flutter run.
- Para un hot restart ('R'): crea un archivo vacio .dart_tool/flutter8080.log.restart
  (el script lo borra solo y manda la tecla).
- La salida de flutter se guarda en .dart_tool/flutter8080.log (esa carpeta no va a git).
- Ctrl+C detiene todo.

El servidor web no recarga la pestana: tras cada reload, refrescala (F5).
"""
import os
import subprocess
import sys
import threading
import time

PROYECTO = os.path.dirname(os.path.abspath(__file__))
LIB = os.path.join(PROYECTO, "lib")
LOG = os.path.join(PROYECTO, ".dart_tool", "flutter8080.log")
RESTART = LOG + ".restart"
LISTO = "is being served at"


def firmas():
    """Fecha de modificacion de cada .dart de lib/ para detectar guardados."""
    r = {}
    for raiz, _, archivos in os.walk(LIB):
        for a in archivos:
            if a.endswith(".dart"):
                p = os.path.join(raiz, a)
                try:
                    r[p] = os.path.getmtime(p)
                except OSError:
                    pass
    return r


def main():
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    if os.path.exists(RESTART):
        os.remove(RESTART)
    log = open(LOG, "w", encoding="utf-8", errors="replace", buffering=1)
    proc = subprocess.Popen(
        "flutter run -d web-server --web-port 8080 --web-hostname localhost",
        cwd=PROYECTO,
        shell=True,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    listo = threading.Event()

    def volcar():
        for linea in iter(proc.stdout.readline, b""):
            texto = linea.decode("utf-8", errors="replace")
            log.write(texto)
            sys.stdout.write(texto)
            sys.stdout.flush()
            if LISTO in texto:
                listo.set()

    threading.Thread(target=volcar, daemon=True).start()

    def mandar(tecla):
        try:
            proc.stdin.write(tecla.encode())
            proc.stdin.flush()
        except OSError:
            pass

    previo = firmas()
    try:
        while proc.poll() is None:
            time.sleep(1)
            if os.path.exists(RESTART):
                os.remove(RESTART)
                mandar("R")
                previo = firmas()
                continue
            actual = firmas()
            if actual != previo:
                time.sleep(0.6)  # deja que termine de guardar
                previo = firmas()
                # Mientras compila por primera vez aun no hay app a la que recargar.
                if listo.is_set():
                    mandar("r")
    except KeyboardInterrupt:
        mandar("q")
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    main()
