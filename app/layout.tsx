import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Gestión de Horarios de Profesionales | TEKER Medical Platform',
  description: 'Sistema empresarial para la configuración de horarios multi-rango y vigencia de disponibilidad para profesionales de salud TEKER.',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="es">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap"
          rel="stylesheet"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
