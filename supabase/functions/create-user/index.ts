// Edge Function para crear usuarios
// Despliega con: supabase functions deploy create-user

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Crear cliente Supabase con service role
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Obtener el token del usuario que hace la petición
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    // Verificar que el usuario tiene permisos
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    
    if (authError || !user) {
      throw new Error('Usuario no autenticado')
    }

    // Verificar que el usuario tiene rol de admin
    const { data: creatorProfile, error: profileError } = await supabaseAdmin
      .from('users')
      .select('role, sede')
      .eq('id', user.id)
      .single()

    if (profileError || !creatorProfile) {
      throw new Error('No se pudo obtener el perfil del usuario')
    }

    if (!['owner', 'supervisor'].includes(creatorProfile.role)) {
      throw new Error('No tienes permisos para crear usuarios')
    }

    // Obtener datos del body
    const { email, password, full_name, role, sede, phone, created_by } = await req.json()

    // Validaciones
    if (!email || !password || !full_name || !role || !sede || !phone) {
      throw new Error('Todos los campos son requeridos')
    }

    // Verificar que supervisor solo crea usuarios de su sede
    if (creatorProfile.role === 'supervisor' && creatorProfile.sede !== sede) {
      throw new Error('Solo puedes crear usuarios para tu sede')
    }

    // Verificar que supervisor solo crea mercaderistas
    if (creatorProfile.role === 'supervisor' && role !== 'mercaderista') {
      throw new Error('Solo puedes crear mercaderistas')
    }

    // Crear usuario en auth
    const { data: authData, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name
      }
    })

    if (createError) {
      if (createError.message.includes('already registered')) {
        throw new Error('El correo electrónico ya está registrado')
      }
      throw createError
    }

    const userId = authData.user.id

    // Determinar la región basada en la sede
    const regionMap: Record<string, string> = {
      'grupo_disbattery': 'centro_capital',
      'disbattery': 'oriente',
      'blitz_2000': 'centro_los_llanos',
      'grupo_victoria': 'occidente'
    }

    // Actualizar el perfil creado por el trigger (on_auth_user_created)
    const { error: updateError } = await supabaseAdmin
      .from('users')
      .update({
        full_name,
        role,
        sede,
        region: regionMap[sede] || null,
        phone,
        status: 'active',
        created_by
      })
      .eq('id', userId)

    if (updateError) {
      // Si falla, eliminar el usuario de auth
      await supabaseAdmin.auth.admin.deleteUser(userId)
      throw new Error(`Error al actualizar perfil: ${updateError.message}`)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        user_id: userId,
        message: 'Usuario creado exitosamente'
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400 
      }
    )
  }
})
