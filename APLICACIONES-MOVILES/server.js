const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

const app = express();
const PORT = 5000;

app.use(express.json());

// ============================================================
// CONFIGURACIÓN JWT
// ============================================================

const ACCESS_TOKEN_SECRET = 'agenda_inteligente_access_secret_2026';
const REFRESH_TOKEN_SECRET = 'agenda_inteligente_refresh_secret_2026';

// 60 segundos para demostrar renovación automática en Semana 13.
const ACCESS_TOKEN_EXPIRES_IN = '60s';
const refreshTokens = new Set();

// ============================================================
// USUARIO DE PRUEBA
// ============================================================

const usuarioDemo = {
  id: 101,
  nombre: 'Mónica',
  email: 'monica@correo.com',
  passwordHash: bcrypt.hashSync('123456', 10),
};

// ============================================================
// BASE DE DATOS DE DEMOSTRACIÓN EN MEMORIA
// ============================================================

let tareas = [
  {
    id: '1',
    client_id: 'server-initial-1',
    titulo: 'Realizar taller de aplicaciones móviles',
    descripcion: '',
    completada: false,
    updated_at: new Date().toISOString(),
  },
];

function generarAccessToken(usuario) {
  return jwt.sign(
    {
      id: usuario.id,
      email: usuario.email,
      nombre: usuario.nombre,
    },
    ACCESS_TOKEN_SECRET,
    { expiresIn: ACCESS_TOKEN_EXPIRES_IN },
  );
}

function generarRefreshToken(usuario) {
  return jwt.sign(
    {
      id: usuario.id,
      email: usuario.email,
    },
    REFRESH_TOKEN_SECRET,
    { expiresIn: '7d' },
  );
}

const verificarAutenticacion = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({
      success: false,
      message: 'Token de acceso requerido',
    });
  }

  const partes = authHeader.split(' ');
  if (partes.length !== 2 || partes[0] !== 'Bearer') {
    return res.status(401).json({
      success: false,
      message: 'Formato de token inválido',
    });
  }

  try {
    req.usuario = jwt.verify(partes[1], ACCESS_TOKEN_SECRET);
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Access token expirado',
      });
    }

    return res.status(401).json({
      success: false,
      message: 'Access token inválido',
    });
  }
};

// ============================================================
// LOGIN + RESPUESTA 422 POR CAMPO
// ============================================================

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  const errors = {};

  if (!email) {
    errors.email = 'El correo electrónico es obligatorio.';
  } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    errors.email = 'Ingrese un correo electrónico válido.';
  }

  if (!password) {
    errors.password = 'La contraseña es obligatoria.';
  } else if (password.length < 6) {
    errors.password = 'La contraseña debe tener al menos 6 caracteres.';
  }

  if (Object.keys(errors).length > 0) {
    return res.status(422).json({
      success: false,
      message: 'Hay campos inválidos.',
      errors,
    });
  }

  if (email !== usuarioDemo.email) {
    return res.status(401).json({
      success: false,
      message: 'Credenciales incorrectas',
    });
  }

  const passwordCorrecta = await bcrypt.compare(
    password,
    usuarioDemo.passwordHash,
  );

  if (!passwordCorrecta) {
    return res.status(401).json({
      success: false,
      message: 'Credenciales incorrectas',
    });
  }

  const accessToken = generarAccessToken(usuarioDemo);
  const refreshToken = generarRefreshToken(usuarioDemo);
  refreshTokens.add(refreshToken);

  console.log('🔐 [LOGIN] Usuario autenticado:', email);

  res.status(200).json({
    success: true,
    usuario: { email: usuarioDemo.email },
    tokens: {
      accessToken,
      refreshToken,
      expiresIn: 60,
    },
  });
});

// ============================================================
// REFRESH TOKEN
// ============================================================

app.post('/api/auth/refresh', (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(401).json({
      success: false,
      message: 'Refresh token requerido',
    });
  }

  if (!refreshTokens.has(refreshToken)) {
    return res.status(401).json({
      success: false,
      message: 'Refresh token inválido',
    });
  }

  try {
    const usuario = jwt.verify(refreshToken, REFRESH_TOKEN_SECRET);
    const newAccessToken = generarAccessToken(usuario);
    const newRefreshToken = generarRefreshToken(usuario);

    refreshTokens.delete(refreshToken);
    refreshTokens.add(newRefreshToken);

    console.log('🔄 [REFRESH] Access token renovado');

    res.status(200).json({
      success: true,
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
      expiresIn: 60,
    });
  } catch (error) {
    refreshTokens.delete(refreshToken);
    return res.status(401).json({
      success: false,
      message: 'Refresh token expirado o inválido',
    });
  }
});

// ============================================================
// GET TAREAS
// ============================================================

app.get('/api/tareas', verificarAutenticacion, (req, res) => {
  console.log('📥 [GET] Usuario:', req.usuario.email);
  res.status(200).json(tareas);
});

// ============================================================
// POST TAREA - IDEMPOTENCIA POR client_id
// ============================================================

app.post('/api/tareas', verificarAutenticacion, (req, res) => {
  const titulo = (req.body.titulo || req.body.title || '').toString().trim();
  const clientId = (req.body.client_id || '').toString().trim();
  const errors = {};

  if (!titulo) errors.titulo = 'El título de la tarea es obligatorio.';
  if (!clientId) errors.client_id = 'El identificador único del cliente es obligatorio.';

  if (Object.keys(errors).length > 0) {
    return res.status(422).json({
      success: false,
      message: 'Hay campos inválidos.',
      errors,
    });
  }

  // Si una creación offline se reintenta, no se duplica.
  const existente = tareas.find((t) => t.client_id === clientId);
  if (existente) {
    return res.status(200).json({
      success: true,
      message: 'La tarea ya estaba sincronizada.',
      tarea: existente,
    });
  }

  const nuevaTarea = {
    id: Date.now().toString(),
    client_id: clientId,
    titulo,
    descripcion: (req.body.descripcion || '').toString(),
    completada: req.body.completada === true,
    // Marca temporal autoritativa del servidor.
    updated_at: new Date().toISOString(),
  };

  tareas.push(nuevaTarea);

  console.log('📤 [POST] Tarea sincronizada:', nuevaTarea);

  res.status(201).json({
    success: true,
    message: 'Tarea sincronizada correctamente',
    tarea: nuevaTarea,
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor listo y escuchando en http://0.0.0.0:${PORT}`);
  console.log('🔐 Login de prueba: monica@correo.com / 123456');
  console.log('⏱️ Access Token: 60 segundos');
});
