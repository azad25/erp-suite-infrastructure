const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const redis = require('redis');
const jwt = require('jsonwebtoken');
const cors = require('cors');

const app = express();
const server = http.createServer(app);

// CORS configuration
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true
}));

// Socket.IO setup with CORS
const io = socketIo(server, {
    cors: {
        origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
        methods: ["GET", "POST"],
        credentials: true
    }
});

// Redis client setup
const redisClient = redis.createClient({
    url: process.env.REDIS_URL || 'redis://localhost:6379'
});

redisClient.on('error', (err) => {
    console.error('Redis Client Error:', err);
});

redisClient.on('connect', () => {
    console.log('✅ Connected to Redis');
});

// Connect to Redis
redisClient.connect();

// JWT middleware for socket authentication
const authenticateSocket = async (socket, next) => {
    try {
        const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');
        
        if (!token) {
            return next(new Error('Authentication token required'));
        }

        // Verify JWT token (you should use your actual JWT secret)
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-super-secret-jwt-key');
        
        // Check if token is blacklisted in Redis
        const isBlacklisted = await redisClient.get(`blacklist:${token}`);
        if (isBlacklisted) {
            return next(new Error('Token is blacklisted'));
        }

        socket.userId = decoded.user_id;
        socket.organizationId = decoded.organization_id;
        socket.email = decoded.email;
        
        next();
    } catch (error) {
        next(new Error('Invalid authentication token'));
    }
};

// Apply authentication middleware
io.use(authenticateSocket);

// Socket connection handling
io.on('connection', (socket) => {
    console.log(`✅ User connected: ${socket.email} (${socket.userId})`);
    
    // Join organization room for tenant isolation
    socket.join(`org:${socket.organizationId}`);
    
    // Join user-specific room
    socket.join(`user:${socket.userId}`);
    
    // Handle real-time events
    socket.on('join_room', (room) => {
        // Validate room access based on organization
        if (room.startsWith(`org:${socket.organizationId}`) || room.startsWith(`user:${socket.userId}`)) {
            socket.join(room);
            socket.emit('joined_room', { room });
            console.log(`User ${socket.email} joined room: ${room}`);
        } else {
            socket.emit('error', { message: 'Access denied to room' });
        }
    });
    
    socket.on('leave_room', (room) => {
        socket.leave(room);
        socket.emit('left_room', { room });
        console.log(`User ${socket.email} left room: ${room}`);
    });
    
    // Handle chat messages
    socket.on('chat_message', (data) => {
        const message = {
            id: Date.now(),
            userId: socket.userId,
            email: socket.email,
            message: data.message,
            room: data.room,
            timestamp: new Date().toISOString()
        };
        
        // Broadcast to room (with organization validation)
        if (data.room.startsWith(`org:${socket.organizationId}`)) {
            io.to(data.room).emit('chat_message', message);
            
            // Store message in Redis for history
            redisClient.lpush(`chat:${data.room}`, JSON.stringify(message));
            redisClient.ltrim(`chat:${data.room}`, 0, 99); // Keep last 100 messages
        }
    });
    
    // Handle notifications
    socket.on('send_notification', (data) => {
        const notification = {
            id: Date.now(),
            from: socket.userId,
            to: data.to,
            type: data.type,
            title: data.title,
            message: data.message,
            timestamp: new Date().toISOString(),
            organizationId: socket.organizationId
        };
        
        // Send to specific user in same organization
        io.to(`user:${data.to}`).emit('notification', notification);
        
        // Store notification in Redis
        redisClient.lpush(`notifications:${data.to}`, JSON.stringify(notification));
        redisClient.ltrim(`notifications:${data.to}`, 0, 49); // Keep last 50 notifications
    });
    
    // Handle business events (from Kafka or other services)
    socket.on('subscribe_events', (eventTypes) => {
        eventTypes.forEach(eventType => {
            socket.join(`events:${eventType}:${socket.organizationId}`);
        });
        socket.emit('subscribed_events', { eventTypes });
    });
    
    // Handle disconnection
    socket.on('disconnect', (reason) => {
        console.log(`❌ User disconnected: ${socket.email} (${reason})`);
    });
    
    // Handle errors
    socket.on('error', (error) => {
        console.error('Socket error:', error);
    });
});

// REST endpoints for WebSocket management
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        service: 'websocket-server',
        connections: io.engine.clientsCount,
        timestamp: new Date().toISOString()
    });
});

// Endpoint to broadcast events to organization
app.post('/broadcast/:organizationId', express.json(), (req, res) => {
    const { organizationId } = req.params;
    const { event, data } = req.body;
    
    io.to(`org:${organizationId}`).emit(event, data);
    
    res.json({ success: true, message: 'Event broadcasted' });
});

// Endpoint to send notification to specific user
app.post('/notify/:userId', express.json(), (req, res) => {
    const { userId } = req.params;
    const notification = req.body;
    
    io.to(`user:${userId}`).emit('notification', notification);
    
    res.json({ success: true, message: 'Notification sent' });
});

// Start server
const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
    console.log(`🚀 WebSocket server running on port ${PORT}`);
    console.log(`📡 Socket.IO endpoint: http://localhost:${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('🛑 Shutting down WebSocket server...');
    server.close(() => {
        redisClient.quit();
        process.exit(0);
    });
});