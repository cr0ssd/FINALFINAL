defmodule JswatchWeb.IndigloManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {:ok, %{ui_pid: ui, st: IndigloOff, count: 0, timer1: nil, snooze_timer: nil}} #Se añadió snooze_timer
  end

    #Cuando se presiona el botón inferior derecho MIENTRAS la alarma parpadea
    def handle_info(:"bottom-right-pressed", %{st: st} = state) when st in [AlarmOn, AlarmOff] do
      IO.puts("Entrando a PreSnooze...")
      # Inicia un temporizador de 2 segundos que enviará :activate_snooze_timeout.
      snooze_timer = Process.send_after(self(), :activate_snooze_timeout, 2000)
      # Se cancela el parpadeo de la alarma que estuviera en curso.
      if state.timer1 != nil, do: Process.cancel_timer(state.timer1)
      #nuevo estado :pre_snooze y guardamos la referencia del temporizador.
      {:noreply, %{state | st: PreSnooze, snooze_timer: snooze_timer}}
    end

    # Si se suelta el botón antes de los 2 segundos.
    def handle_info(:"bottom-right-released", %{st: PreSnooze, ui_pid: pid, snooze_timer: snooze_timer} = state) do
      IO.puts("Snooze cancelado, alarma apagada.")
      # Se cancela el temporizador del snooze que estaba corriendo.
      Process.cancel_timer(snooze_timer)
      # Se apaga el indiglo.
      GenServer.cast(pid, :unset_indiglo)
      # Regresamos al estado IndigloOff, terminando la alarma por completo.
      {:noreply, %{state | st: IndigloOff, count: 0, snooze_timer: nil}}
    end

    #Si pasan los 2 segundos en PreSnooze.
    def handle_info(:activate_snooze_timeout, %{st: PreSnooze, ui_pid: pid} = state) do
      IO.puts("Snooze activado!")
      # Se apaga el indiglo, como lo pide el statechart.
      GenServer.cast(pid, :unset_indiglo)
      # Se envía el evento :update_alarm para que lo capture el ClockManager.
      :gproc.send({:p, :l, :ui_event}, :update_alarm)
      # La alarma se apaga y el reloj vuelve a la normalidad, esperando los nuevos 10 segundos.
      {:noreply, %{state | st: IndigloOff, count: 0, snooze_timer: nil}}
    end

    def handle_info(:"top-right-pressed", %{ui_pid: pid, st: IndigloOff} = state) do
      GenServer.cast(pid, :set_indiglo)
      {:noreply, %{state | st: IndigloOn}}
    end

    def handle_info(:"top-right-released", %{st: IndigloOn} = state) do
      timer = Process.send_after(self(), :waiting_indiglo_off, 2000)
      {:noreply, %{state | st: Waiting, timer1: timer}}
    end

  def handle_info(:"top-left-pressed", state) do
    :gproc.send({:p, :l, :ui_event}, :update_alarm)
    {:noreply, state}
  end

  def handle_info(:waiting_indiglo_off, %{ui_pid: pid, st: Waiting} = state) do
    GenServer.cast(pid, :unset_indiglo)
    {:noreply, %{state | st: IndigloOff}}
  end

  def handle_info(:start_alarm, %{ui_pid: pid, st: IndigloOff} = state) do
    timer = Process.send_after(self(), :alarm_on_alarm_off, 500)
    GenServer.cast(pid, :set_indiglo)
    {:noreply, %{state | count: 51, st: AlarmOn, timer1: timer}}
  end

  def handle_info(:start_alarm, %{st: IndigloOn} = state) do
    timer = Process.send_after(self(), :alarm_off_alarm_on, 500)
    {:noreply, %{state | count: 51, st: AlarmOff, timer1: timer}}
  end

  def handle_info(:alarm_on_alarm_off, %{ui_pid: pid, count: count, st: AlarmOn} = state) do
    if count >= 1 do
      timer = Process.send_after(self(), :alarm_off_alarm_on, 500)
      GenServer.cast(pid, :unset_indiglo)
      {:noreply, %{state | count: count - 1, st: AlarmOff, timer1: timer}}
    else
      GenServer.cast(pid, :unset_indiglo)
      {:noreply, %{state | count: 0, st: IndigloOff}}
    end
  end #Modificado también para manejar el timer1


  def handle_info(:alarm_off_alarm_on, %{ui_pid: pid, count: count, st: AlarmOff} = state) do
    if count >= 1 do
      timer = Process.send_after(self(), :alarm_on_alarm_off, 500)
      GenServer.cast(pid, :set_indiglo)
      {:noreply, %{state | count: count - 1, st: AlarmOn, timer1: timer}}
    else
      GenServer.cast(pid, :unset_indiglo)
      {:noreply, %{state | count: 0, st: IndigloOff}}
    end
  end

  def handle_info(_event, state) do
    # IO.inspect({:unhandled_indiglo, event, state.st})
    {:noreply, state}
  end
end
