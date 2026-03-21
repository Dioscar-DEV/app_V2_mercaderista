# Modulo Material POP - Ingreso y Egreso

## Que es

Sistema de control de inventario de material publicitario (POP) por sede. Permite registrar ingresos de material recibido y egresos manuales o automaticos cuando los mercaderistas lo usan en visitas.

## Tablas en Supabase

| Tabla | Funcion |
|---|---|
| `pop_materials` | Catalogo de materiales (60+ items Shell/Qualid) |
| `pop_stock` | Stock actual por sede + material |
| `pop_movements` | Historial de ingresos y egresos |

## Flujo

### Ingreso (Supervisor/Admin)
1. Modulo "Material POP" en el dashboard
2. Boton "Registrar" → selecciona "Ingreso"
3. Selecciona materiales y cantidades
4. Stock se actualiza automaticamente via trigger

### Egreso Manual (Supervisor/Admin)
Mismo flujo pero seleccionando "Egreso". El stock se resta (puede ir a negativo).

### Egreso Automatico (desde visitas)
Si un material esta **vinculado** a una pregunta del formulario, se resta automaticamente cuando un mercaderista completa una visita.

**Ejemplo:** Material "VASOS SHELL" vinculado a pregunta "Entregables Shell" opcion "Vasos Shell". Si el mercaderista marca "Vasos Shell: 10", se restan 10 del stock de su sede.

## Vinculacion de materiales

Desde la pantalla de edicion de un material:
1. Activar "Vincular a formulario de visita"
2. Seleccionar la pregunta (dropdown)
3. Seleccionar la opcion (dropdown dinamico)
4. Guardar

**Sin vinculacion** = solo control manual (ingreso/egreso desde el modulo)

## Triggers en Supabase

| Trigger | Tabla | Funcion |
|---|---|---|
| `trg_update_pop_stock` | `pop_movements` | Actualiza stock al registrar movimiento |
| `trg_auto_egreso_pop_answers` | `route_visit_answers` | Resta stock automatico si hay vinculacion |

## Permisos

- **Owner**: Ve todas las sedes
- **Supervisor**: Ve solo su sede
- **Mercaderista**: No tiene acceso al modulo (el egreso es automatico desde visitas)

## Archivos Flutter

```
lib/core/models/pop_material.dart          - Modelos (PopMaterial, PopStock, PopMovement)
lib/presentation/providers/pop_provider.dart - Providers Riverpod
lib/presentation/screens/admin/material_pop/
  material_pop_screen.dart                  - Pantalla principal (Stock + Movimientos)
  register_movement_screen.dart             - Registrar ingreso/egreso
  edit_material_screen.dart                 - Crear/editar/vincular material
```
