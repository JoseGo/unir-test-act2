import http.client
import os
import unittest
from urllib.request import urlopen
from urllib.error import HTTPError

import pytest

BASE_URL = os.environ.get("BASE_URL")
DEFAULT_TIMEOUT = 2  # in secs


@pytest.mark.api
class TestApi(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(BASE_URL, "URL no configurada")
        self.assertTrue(len(BASE_URL) > 8, "URL no configurada")

    def test_api_add(self):
        url = f"{BASE_URL}/calc/add/2/2"
        response = urlopen(url, timeout=DEFAULT_TIMEOUT)
        self.assertEqual(
            response.status, http.client.OK, f"Error en la petición API a {url}"
        )

    # Test fail add
    def test_api_add_invalid_input(self):
        url = f"{BASE_URL}/calc/add/a/b"
        try:
            urlopen(url, timeout=DEFAULT_TIMEOUT)
            self.fail("La API debería lanzar un error con parámetros no numéricos")
        except HTTPError as e:
            self.assertEqual(
            e.code, http.client.BAD_REQUEST,
            f"Se esperaba 400 Bad Request para entrada inválida, se obtuvo {e.code}"
        )
            
    #Test correct substract
    def test_api_substract_success(self):
        url = f"{BASE_URL}/calc/substract/10/4"
        response = urlopen(url, timeout=DEFAULT_TIMEOUT)
        self.assertEqual(response.status, http.client.OK)

        body = response.read().decode()
        self.assertEqual(body, "6")
    
    #Test fail substract
    def test_api_substract_invalid_input(self):
        url = f"{BASE_URL}/calc/substract/a/b"
        try:
            urlopen(url, timeout=DEFAULT_TIMEOUT)
            self.fail("La API debería lanzar un error con parámetros no numéricos")
        except HTTPError as e:
            self.assertEqual(
            e.code, http.client.BAD_REQUEST,
            f"Se esperaba 400 Bad Request para entrada inválida, se obtuvo {e.code}"
        )    
    
    # Test correct divide
    def test_api_divide_success(self):
        url = f"{BASE_URL}/calc/divide/10/2"
        response = urlopen(url, timeout=DEFAULT_TIMEOUT)
        self.assertEqual(response.status, http.client.OK)
        body = response.read().decode()
        self.assertEqual(body, "5.0")

    # Test fail divide
    def test_api_divide_invalid_input(self):
        url = f"{BASE_URL}/calc/divide/10/a"
        try:
            urlopen(url, timeout=DEFAULT_TIMEOUT)
            self.fail("La API debería devolver 400 Bad Request con parámetros inválidos")
        except HTTPError as e:
            self.assertEqual(
                e.code, http.client.BAD_REQUEST,
                f"Se esperaba 400 Bad Request, se obtuvo {e.code}"
            )

    # Test fail divide
    def test_api_divide_by_zero(self):
        url = f"{BASE_URL}/calc/divide/10/0"
        try:
            urlopen(url, timeout=DEFAULT_TIMEOUT)
            self.fail("La división por cero debería devolver 400 Bad Request")
        except HTTPError as e:
            self.assertEqual(
                e.code, http.client.BAD_REQUEST,
                "Se esperaba 400 Bad Request por división entre cero"
            )

    # Test correct square_root
    def test_api_square_root_success(self):
        url = f"{BASE_URL}/calc/square_root/16"
        response = urlopen(url, timeout=DEFAULT_TIMEOUT)
        self.assertEqual(response.status, http.client.OK)
        body = response.read().decode()
        self.assertEqual(body, "4.0")

    # Test fail square_root
    def test_api_square_root_negative(self):
        url = f"{BASE_URL}/calc/square_root/-9"
        try:
            urlopen(url, timeout=DEFAULT_TIMEOUT)
            self.fail("La raíz de un número negativo debería dar 400 Bad Request")
        except HTTPError as e:
            self.assertEqual(
                e.code, http.client.BAD_REQUEST,
                "Se esperaba 400 Bad Request por raíz de número negativo"
            )

    # Test correct log_base_10
    def test_api_log_base_10_success(self):
        url = f"{BASE_URL}/calc/log_base_10/1000"
        response = urlopen(url, timeout=DEFAULT_TIMEOUT)
        self.assertEqual(response.status, http.client.OK)

        body = response.read().decode()
        self.assertEqual(body, "3.0")

    # Test failed log_base_10
    def test_api_log_base_10_invalid_input(self):
        url = f"{BASE_URL}/calc/log_base_10/0"
        try:
            urlopen(url, timeout=DEFAULT_TIMEOUT)
            self.fail("El logaritmo de un número negativo debería dar 400 Bad Request")
        except HTTPError as e:
            self.assertEqual(
                e.code, http.client.BAD_REQUEST,
                "Se esperaba 400 Bad Request por log de número negativo"
            )
            body = e.read().decode()
            self.assertIn("Logarithm base 10 is only defined for positive numbers", body)


