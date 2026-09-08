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

// Access Token: 60 segundos para demostrar el refresh
const ACCESS_TOKEN_EXPIRES_IN = '60s';

// Refresh tokens almacenados temporalmente en memoria
const refreshTokens = new Set();

// ============================================================
// USUARIO DE PRUEBA
// ============================================================

const usuarioDemo = {
    id: 101,
    nombre: 'Mónica',
    email: 'monica@correo.com',

    // Contraseña de prueba:
    // 123456
    passwordHash: bcrypt.hashSync('123456', 10)
};

// ============================================================
// BASE DE DATOS EN MEMORIA
// ============================================================

let tareas = [
    {
        id: 1,
        titulo: 'Realizar taller de aplicaciones móviles',
        estado: 'Pendiente'
    }
];

// ============================================================
// CREAR ACCESS TOKEN
// ============================================================

function generarAccessToken(usuario) {
    return jwt.sign(
        {
            id: usuario.id,
            email: usuario.email,
            nombre: usuario.nombre
        },
        ACCESS_TOKEN_SECRET,
        {
            expiresIn: ACCESS_TOKEN_EXPIRES_IN
        }
    );
}

// ============================================================
// CREAR REFRESH TOKEN
// ============================================================

function generarRefreshToken(usuario) {
    return jwt.sign(
        {
            id: usuario.id,
            email: usuario.email
        },
        REFRESH_TOKEN_SECRET,
        {
            expiresIn: '7d'
        }
    );
}

// ============================================================
// MIDDLEWARE DE AUTENTICACIÓN
// ============================================================

const verificarAutenticacion = (req, res, next) => {

    const authHeader = req.headers.authorization;

    if (!authHeader) {
        return res.status(401).json({
            success: false,
            message: 'Token de acceso requerido'
        });
    }

    const partes = authHeader.split(' ');

    if (
        partes.length !== 2 ||
        partes[0] !== 'Bearer'
    ) {
        return res.status(401).json({
            success: false,
            message: 'Formato de token inválido'
        });
    }

    const token = partes[1];

    try {

        const usuario = jwt.verify(
            token,
            ACCESS_TOKEN_SECRET
        );

        req.usuario = usuario;

        next();

    } catch (error) {

        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({
                success: false,
                message: 'Access token expirado'
            });
        }

        return res.status(401).json({
            success: false,
            message: 'Access token inválido'
        });
    }
};

// ============================================================
// LOGIN
// ============================================================

app.post('/api/auth/login', async (req, res) => {

    const { email, password } = req.body;

    // Validación 422
    if (!email || !password) {
        return res.status(422).json({
            success: false,
            message: 'El correo y la contraseña son obligatorios'
        });
    }

    // Verificar correo
    if (email !== usuarioDemo.email) {
        return res.status(401).json({
            success: false,
            message: 'Credenciales incorrectas'
        });
    }

    // Verificar contraseña
    const passwordCorrecta =
        await bcrypt.compare(
            password,
            usuarioDemo.passwordHash
        );

    if (!passwordCorrecta) {
        return res.status(401).json({
            success: false,
            message: 'Credenciales incorrectas'
        });
    }

    // Crear tokens
    const accessToken =
        generarAccessToken(usuarioDemo);

    const refreshToken =
        generarRefreshToken(usuarioDemo);

    // Guardar refresh token
    refreshTokens.add(refreshToken);

    console.log('🔐 [LOGIN] Usuario autenticado:', email);

    res.status(200).json({

        success: true,

        usuario: {
            email: usuarioDemo.email
        },

        tokens: {
            accessToken,
            refreshToken,
            expiresIn: 60
        }
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
            message: 'Refresh token requerido'
        });
    }

    // Verificar que exista
    if (!refreshTokens.has(refreshToken)) {
        return res.status(401).json({
            success: false,
            message: 'Refresh token inválido'
        });
    }

    try {

        const usuario = jwt.verify(
            refreshToken,
            REFRESH_TOKEN_SECRET
        );

        // Crear nuevo access token
        const newAccessToken =
            generarAccessToken(usuario);

        // Crear nuevo refresh token
        const newRefreshToken =
            generarRefreshToken(usuario);

        // Rotación del refresh token
        refreshTokens.delete(refreshToken);
        refreshTokens.add(newRefreshToken);

        console.log('🔄 [REFRESH] Access token renovado');

        res.status(200).json({

            success: true,

            accessToken: newAccessToken,

            refreshToken: newRefreshToken,

            expiresIn: 60
        });

    } catch (error) {

        refreshTokens.delete(refreshToken);

        return res.status(401).json({
            success: false,
            message: 'Refresh token expirado o inválido'
        });
    }
});

// ============================================================
// GET TAREAS
// ============================================================

app.get(
    '/api/tareas',
    verificarAutenticacion,
    (req, res) => {

        console.log(
            '📥 [GET] Petición autenticada recibida desde el celular.'
        );

        console.log(
            '👤 Usuario:',
            req.usuario.email
        );

        res.status(200).json(tareas);
    }
);

// ============================================================
// POST TAREA
// ============================================================

app.post(
    '/api/tareas',
    verificarAutenticacion,
    (req, res) => {

        console.log(
            '📤 [POST] Recibiendo tarea para sincronizar:',
            req.body
        );

        const tituloTarea =
            req.body.titulo ||
            req.body.title ||
            'Nueva tarea';

        const nuevaTarea = {
            id: Date.now(),
            titulo: tituloTarea,
            estado: 'Pendiente'
        };

        tareas.push(nuevaTarea);

        res.status(201).json({
            success: true,
            message: 'Tarea sincronizada correctamente',
            tarea: nuevaTarea
        });
    }
);

// ============================================================
// INICIAR SERVIDOR
// ============================================================

app.listen(PORT, '0.0.0.0', () => {

    console.log(
        `🚀 Servidor listo y escuchando en http://0.0.0.0:${PORT}`
    );

    console.log(
        '🔐 Login de prueba: monica@correo.com / 123456'
    );

    console.log(
        '⏱️ Access Token: 60 segundos'
    );
});