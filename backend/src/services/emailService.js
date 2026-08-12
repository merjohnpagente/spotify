const nodemailer = require('nodemailer');
const config = require('../config');

let transporter = null;

const createTransporter = () => {
  if (!config.mailgun.apiKey || !config.mailgun.domain) {
    console.warn('Mailgun not configured, emails will be logged only');
    return null;
  }

  if (transporter) return transporter;

  transporter = nodemailer.createTransport({
    host: 'smtp.mailgun.org',
    port: 587,
    secure: false,
    auth: {
      user: 'postmaster@' + config.mailgun.domain,
      pass: config.mailgun.apiKey,
    },
  });

  return transporter;
};

const sendEmail = async (to, subject, html, text) => {
  const transporter = createTransporter();
  
  if (!transporter) {
    console.log('EMAIL (dev mode):', { to, subject, text });
    return { success: true, messageId: 'dev-mode' };
  }

  try {
    const info = await transporter.sendMail({
      from: config.mailgun.fromEmail,
      to,
      subject,
      text,
      html,
    });
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('Email send error:', error);
    return { success: false, error: error.message };
  }
};

const sendWelcomeEmail = async (email, username) => {
  const subject = 'Welcome to Spotify Clone!';
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h1 style="color: #1DB954;">Welcome to Spotify Clone, ${username}!</h1>
      <p>Thanks for joining us. Start exploring millions of songs for free.</p>
      <a href="${config.frontend.url}" style="background: #1DB954; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">Open App</a>
    </div>
  `;
  const text = `Welcome to Spotify Clone, ${username}! Visit ${config.frontend.url} to start listening.`;
  return sendEmail(email, subject, html, text);
};

const sendPasswordResetEmail = async (email, resetToken) => {
  const resetUrl = `${config.frontend.url}/reset-password?token=${resetToken}`;
  const subject = 'Reset Your Password';
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h1 style="color: #1DB954;">Password Reset</h1>
      <p>Click the button below to reset your password. This link expires in 1 hour.</p>
      <a href="${resetUrl}" style="background: #1DB954; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">Reset Password</a>
      <p style="color: #666; font-size: 12px;">If you didn't request this, please ignore this email.</p>
    </div>
  `;
  const text = `Reset your password: ${resetUrl} (expires in 1 hour)`;
  return sendEmail(email, subject, html, text);
};

const sendEmailVerification = async (email, verificationToken) => {
  const verifyUrl = `${config.frontend.url}/verify-email?token=${verificationToken}`;
  const subject = 'Verify Your Email';
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h1 style="color: #1DB954;">Verify Your Email</h1>
      <p>Click the button below to verify your email address.</p>
      <a href="${verifyUrl}" style="background: #1DB954; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">Verify Email</a>
    </div>
  `;
  const text = `Verify your email: ${verifyUrl}`;
  return sendEmail(email, subject, html, text);
};

const sendFollowNotification = async (email, followerName) => {
  const subject = `${followerName} started following you`;
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h1 style="color: #1DB954;">New Follower</h1>
      <p><strong>${followerName}</strong> started following you on Spotify Clone.</p>
      <a href="${config.frontend.url}/profile" style="background: #1DB954; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">View Profile</a>
    </div>
  `;
  const text = `${followerName} started following you. View your profile at ${config.frontend.url}/profile`;
  return sendEmail(email, subject, html, text);
};

module.exports = {
  sendEmail,
  sendWelcomeEmail,
  sendPasswordResetEmail,
  sendEmailVerification,
  sendFollowNotification,
};