defmodule JswatchWeb.ClockManager do
  use GenServer

  def init(ui) do
    :gproc.reg({:p, :l, :ui_event})
    {_, now} = :calendar.local_time()
    time = Time.from_erl!(now)
    alarm = Time.add(time, 10)
    Process.send_after(self(), :working_working, 1000)
    {:ok, %{ui_pid: ui, time: time, alarm: alarm, st: Working}}
  end

  # Se cambia de 5 a 10 segundos.
  def handle_info(:update_alarm, state) do
    IO.puts("ClockManager: Recibido update_alarm. Recalculando alarma...")
    # Ahora usa el tiempo actual del estado para calcular la nueva alarma.
    new_alarm_time = Time.add(state.time, 10)
    {:noreply, %{state | alarm: new_alarm_time}}
  end

  def handle_info(:working_working, %{ui_pid: ui, time: time, alarm: alarm, st: Working} = state) do
    Process.send_after(self(), :working_working, 1000)
    time = Time.add(time, 1)
    #Ahora ignora milisegundos
    if Time.truncate(time, :second) == Time.truncate(alarm, :second) do
      IO.puts("ALARM!!!")
      :gproc.send({:p, :l, :ui_event}, :start_alarm)
    end
    GenServer.cast(ui, {:set_time_display, Time.truncate(time, :second) |> Time.to_string()})
    {:noreply, state |> Map.put(:time, time)}
  end

  def handle_info(_event, state), do: {:noreply, state}
end


#PARA COMMIT FINAL
